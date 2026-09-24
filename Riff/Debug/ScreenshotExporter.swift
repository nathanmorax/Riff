//
//  ScreenshotExporter.swift
//  Riff
//
//  Created by Satori Tech 341 on 24/09/26.
//
#if DEBUG
import SwiftUI
import AppKit

// MARK: - Capturas para la App Store (solo Debug)

/// Exporta la interfaz real de Knob a 4× con `ImageRenderer`: texto e íconos se dibujan como vectores,
/// así que quedan nítidos a cualquier tamaño (una captura de pantalla da como máximo 2×).
///
/// Uso: Edit Scheme → Run → Arguments → `-exportScreenshots`, y correr **Knob Dev**.
/// La app busca populares, reproduce una estación, espera a que suene y guarda:
/// `welcome.png`, `player.png` y `search.png` en Application Support/Knob Screenshots/<idioma> (contenedor de la app).
/// Para otro idioma, cambia App Language en el esquema y vuelve a correr.
@MainActor
enum ScreenshotExporter {

    static let scale: CGFloat = 4
    private static let popoverRadius: CGFloat = 13

    static func runIfRequested(player: PlayerViewModel, repository: any StationRepository) {
        guard CommandLine.arguments.contains("-exportScreenshots") else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            await export(player: player, repository: repository)
        }
    }

    static func export(player: PlayerViewModel, repository: any StationRepository) async {
        let folder = outputFolder()
        print("[Knob] 📸 Preparando capturas…")

        // 1. Populares, como los ve el usuario al abrir la búsqueda.
        let results = SearchViewModel(player: player, repository: repository)
        results.present()
        await waitUntil(seconds: 20) { !results.stations.isEmpty }

        // 2. Algo sonando: la última estación o, si no hay, la primera popular.
        if player.currentStation == nil, let first = results.stations.first {
            player.play(first)
        } else {
            player.play()
        }
        await waitUntil(seconds: 20) { player.isPlaying }
        await waitUntil(seconds: 8) { player.nowPlaying != nil } // título en vivo, si la estación lo manda

        // 3. Logos descargados antes de renderizar.
        var stations = Array(results.stations.prefix(6)) + player.recents
        if let current = player.currentStation { stations.append(current) }
        await preloadLogos(for: stations)

        // 4. Render.
        let emptyPlayer = PlayerViewModel(audio: SilentAudio(), library: EmptyLibrary())
        let emptySearch = SearchViewModel(player: emptyPlayer, repository: repository)
        let idleSearch = SearchViewModel(player: player, repository: repository)

        save(popover(PlayerView(player: emptyPlayer, search: emptySearch, isSnapshot: true)), as: "welcome", in: folder)
        save(popover(PlayerView(player: player, search: idleSearch, isSnapshot: true)), as: "player", in: folder)
        save(panel(SearchResultsView(search: results, player: player, isSnapshot: true)), as: "search", in: folder)

        player.stop()
        // El sandbox no deja abrir Finder en el contenedor: se imprime el comando para copiarlas.
        print("[Knob] 📸 Listo: \(folder.path)")
        print("[Knob] 📸 Para copiarlas al proyecto, en Terminal:")
        print("cp -R \"\(folder.deletingLastPathComponent().path)/\" ~/Downloads/Developer/Riff/Marketing/Exports/")
    }

    // MARK: Marcos (como se ven en pantalla)

    /// El popover del MenuBarExtra: negro, esquinas redondeadas y un filo sutil.
    private static func popover(_ content: some View) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: popoverRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: popoverRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .environment(\.colorScheme, .dark)
    }

    /// El panel flotante de resultados (mismo estilo que `FloatingPanelContainer`).
    private static func panel(_ content: some View) -> some View {
        content
            .frame(width: 300, height: 360)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
            )
            .environment(\.colorScheme, .dark)
    }

    // MARK: Archivo

    private static func save(_ view: some View, as name: String, in folder: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = false

        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            print("[Knob] ❌ No se pudo renderizar \(name)")
            return
        }

        do {
            try data.write(to: folder.appending(path: "\(name).png"))
            print("[Knob] 📸 \(name).png — \(image.width)×\(image.height)")
        } catch {
            print("[Knob] ❌ \(name): \(error)")
        }
    }

    /// Application Support/Knob Screenshots/<idioma>, dentro del contenedor de la app.
    /// No se usa Imágenes: en el sandbox es un enlace a ~/Pictures y la app no tiene permiso para escribir ahí.
    private static func outputFolder() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let folder = support.appending(path: "Knob Screenshots/\(language)")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            print("[Knob] ❌ No se pudo crear la carpeta: \(error)")
        }
        return folder
    }

    // MARK: Ayudas

    private static func preloadLogos(for stations: [Station]) async {
        for station in stations {
            guard let url = station.faviconURL, StationTile.snapshotImages[url] == nil else { continue }
            if let response = try? await URLSession.shared.data(from: url), let image = NSImage(data: response.0) {
                StationTile.snapshotImages[url] = image
            }
        }
    }

    private static func waitUntil(seconds: Double, _ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}

// MARK: - Dobles para la pantalla de bienvenida (sin estación, sin audio)

private final class SilentAudio: AudioStreaming {
    let statusUpdates = AsyncStream<PlaybackStatus> { _ in }
    let titleUpdates = AsyncStream<String> { _ in }
    func play(url: URL) {}
    func stop() {}
}

private struct EmptyLibrary: LibraryRepository {
    var lastStation: Station? { nil }
    var recentStations: [Station] { [] }
    func recordPlayback(of station: Station) {}
}
#endif
