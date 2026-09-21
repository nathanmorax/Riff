//
//  ContentView 2.swift
//  Riff
//
//  Created by Satori Tech 341 on 19/09/26.
//
import SwiftUI
@preconcurrency import AVFoundation

// MARK: - Model

struct Station: Codable, Identifiable {
    let stationUUID: String
    let name: String
    let urlResolved: String
    let favicon: String?
    let tags: String
    let bitrate: Int
    let clickcount: Int?

    var id: String {
        stationUUID
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        var clean = trimmed
        for separator in [" - ", " – ", " — ", " | "] {
            if let range = clean.range(of: separator) {
                clean = String(clean[..<range.lowerBound])
            }
        }

        // "UNIVERSAL 88.1 (CDMX)" -> "UNIVERSAL 88.1"
        clean = clean.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        // Si la limpieza se comió casi todo, mejor el nombre original.
        return clean.count >= 2 ? clean : trimmed
    }

    /// Primeros géneros de la estación: "pop · rock · mexicana".
    var genres: String {
        tags
            .split(separator: ",")
            .prefix(3)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Muchos favicons vienen por http://, que App Transport Security bloquea.
    /// Probamos con https://; si el servidor no lo soporta, se queda el placeholder.
    var faviconURL: URL? {
        guard var favicon = favicon?.trimmingCharacters(in: .whitespacesAndNewlines),
              !favicon.isEmpty else { return nil }

        favicon = favicon.replacingOccurrences(of: "http://", with: "https://", options: .anchored)
        return URL(string: favicon)
    }

    enum CodingKeys: String, CodingKey {
        case stationUUID = "stationuuid"
        case name
        case urlResolved = "url_resolved"
        case favicon
        case tags
        case bitrate
        case clickcount
    }
}

// MARK: - API

enum RadioAPI {

    private static let baseURL = "https://de1.api.radio-browser.info"
    private static let countryCode: String? = "MX" // pon nil para buscar en todo el mundo
    private static let limit = 20

    /// Busca `query` como nombre y como género a la vez, y combina los resultados.
    static func stations(matching query: String) async throws -> [Station] {

        // Sin texto: mostramos lo más popular, como antes.
        if query.isEmpty {
            return try await fetch(filter: URLQueryItem(name: "tag", value: "rock"))
        }

        // Las dos peticiones corren en paralelo.
        async let byName = fetch(filter: URLQueryItem(name: "name", value: query))
        async let byGenre = fetch(filter: URLQueryItem(name: "tag", value: query))

        let (nameResults, genreResults) = try await (byName, byGenre)

        // Quitamos duplicados, ordenamos por popularidad y recortamos.
        var seen = Set<String>()
        let merged = (nameResults + genreResults)
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.clickcount ?? 0) > ($1.clickcount ?? 0) }
            .prefix(limit)

        return Array(merged)
    }

    private static func fetch(filter: URLQueryItem) async throws -> [Station] {

        var components = URLComponents(string: baseURL)
        components?.path = "/json/stations/search"

        var items = [
            filter,
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "hidebroken", value: "true")
        ]

        if let countryCode {
            items.append(URLQueryItem(name: "countrycode", value: countryCode))
        }

        components?.queryItems = items

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Riff/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        return try JSONDecoder().decode([Station].self, from: data)
    }
}

// MARK: - AVPlayer + AsyncStream

extension AVPlayer {

    /// Convierte el KVO de `timeControlStatus` en un AsyncStream.
    /// Emite el valor actual al empezar y luego cada cambio.
    ///
    /// Se lee el valor del propio player: `change.newValue` es nil para
    /// estas propiedades enum de Objective-C.
    var timeControlStatusStream: AsyncStream<AVPlayer.TimeControlStatus> {
        AsyncStream { continuation in
            let observation = observe(
                \.timeControlStatus,
                options: [.initial, .new]
            ) { player, _ in
                continuation.yield(player.timeControlStatus)
            }

            continuation.onTermination = { _ in
                observation.invalidate()
            }
        }
    }
}

// MARK: - Timed metadata (título dentro del stream)

/// Lee la metadata en vivo del stream (ICY / ID3) y la expone como AsyncStream.
/// Un `AVPlayerItemMetadataOutput` solo se puede añadir a un item, así que
/// se crea uno nuevo por cada estación.
/// Solo las estaciones que mandan el título en el stream lo mostrarán.
final class TimedMetadataReader: NSObject, AVPlayerItemMetadataOutputPushDelegate, @unchecked Sendable {

    let output = AVPlayerItemMetadataOutput(identifiers: nil)
    let titles: AsyncStream<String>

    private let continuation: AsyncStream<String>.Continuation

    private static let titleIdentifiers: Set<AVMetadataIdentifier> = [
        .icyMetadataStreamTitle,        // radios Shoutcast / Icecast
        .id3MetadataTitleDescription,   // streams HLS con ID3
        .commonIdentifierTitle
    ]

    override init() {
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        self.titles = stream
        self.continuation = continuation
        super.init()
        output.setDelegate(self, queue: .main)
    }

    deinit {
        continuation.finish()
    }

    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        let continuation = self.continuation

        for item in groups.flatMap(\.items) {
            Task {
                let value = try? await item.load(.stringValue)

                // Imprime todo lo que llega, aunque no sea un título.
                print("[Riff] 🎵 metadata [\(item.identifier?.rawValue ?? "sin identificador")] = \(value ?? "nil")")

                guard let identifier = item.identifier,
                      Self.titleIdentifiers.contains(identifier),
                      let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !clean.isEmpty else { return }

                continuation.yield(clean)
            }
        }
    }
}

// MARK: - Marquee

enum Marquee {

    /// Si el texto cabe, lo devuelve tal cual; si no, una ventana de `width`
    /// caracteres que se desplaza en bucle.
    static func window(of text: String, step: Int, width: Int) -> String {
        let chars = Array(text)
        guard chars.count > width else { return text }

        let looped = chars + Array("   •   ")
        let start = step % looped.count

        return String((0..<width).map { looped[(start + $0) % looped.count] })
    }
}

/// Reloj que incrementa `frame` cada cierto intervalo mientras está activo.
@MainActor
@Observable
final class FrameTicker {

    private(set) var frame = 0

    // `nonisolated(unsafe)` para poder cancelarlo desde deinit. Solo se escribe en el MainActor.
    @ObservationIgnored nonisolated(unsafe) private var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }

    func start(every interval: Duration = .milliseconds(150)) {
        guard task == nil else { return }

        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                self.frame &+= 1
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func reset() {
        frame = 0
    }
}

// MARK: - Player

@MainActor
@Observable
final class RadioPlayer {

    /// Estación seleccionada: la que suena o la última que se escuchó.
    /// Se recuerda entre lanzamientos; es `nil` solo la primera vez.
    private(set) var currentStation: Station?
    private(set) var nowPlaying: String?
    private(set) var isPlaying = false
    private(set) var isLoading = false

    /// Sonando o conectando.
    var isActive: Bool {
        isPlaying || isLoading
    }

    /// Reloj de la marquesina; solo corre cuando el texto no cabe en la barra de menú.
    let ticker = FrameTicker()

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var metadataReader: TimedMetadataReader?

    // `nonisolated(unsafe)` para poder cancelarlos desde deinit. Solo se escriben en el MainActor.
    @ObservationIgnored nonisolated(unsafe) private var statusTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var metadataTask: Task<Void, Never>?

    private static let lastStationKey = "lastStation"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentStation = Self.loadLastStation(from: defaults)

        let stream = player.timeControlStatusStream

        statusTask = Task { [weak self] in
            for await status in stream {
                guard let self else { return }
                self.isPlaying = (status == .playing)
                self.isLoading = (status == .waitingToPlayAtSpecifiedRate)
                self.updateTicker()
            }
        }
    }

    deinit {
        statusTask?.cancel()
        metadataTask?.cancel()
    }

    // MARK: Menu bar

    /// Caracteres visibles del texto en la barra de menú; si no caben, se desplaza.
    static let menuBarWidth = 24

    /// Título de la canción o, si la estación no lo manda, el nombre de la estación.
    private var menuBarTitle: String {
        nowPlaying ?? currentStation?.displayName ?? ""
    }

    /// Ventana visible del título; se desplaza cuando es más largo que `menuBarWidth`.
    var menuBarText: String {
        Marquee.window(of: menuBarTitle, step: ticker.frame / 2, width: Self.menuBarWidth)
    }

    /// El reloj solo corre si suena algo y el texto no cabe.
    private func updateTicker() {
        if isPlaying, menuBarTitle.count > Self.menuBarWidth {
            ticker.start()
        } else {
            ticker.stop()
            ticker.reset()
        }
    }

    // MARK: Control

    /// Reanuda la estación seleccionada (la última que se escuchó).
    func play() {
        guard let station = currentStation, !isActive else { return }
        play(station)
    }

    /// Reproduce `station` y la recuerda como última estación.
    func play(_ station: Station) {
        guard let url = URL(string: station.urlResolved) else {
            print("[Riff] ❌ URL inválida: \(station.urlResolved)")
            return
        }

        print("[Riff] ▶️ Reproduciendo: \(station.displayName)")

        currentStation = station
        save(station)
        nowPlaying = nil
        ticker.reset()
        updateTicker()

        let item = AVPlayerItem(url: url)

        // Metadata dentro del stream: si la estación manda el título, llega aquí.
        let reader = TimedMetadataReader()
        item.add(reader.output)
        metadataReader = reader

        metadataTask?.cancel()
        metadataTask = Task { [weak self] in
            for await title in reader.titles {
                guard let self else { return }
                self.applyTitle(title)
            }
        }

        player.replaceCurrentItem(with: item)
        player.play()
    }

    /// Detiene la reproducción. La estación sigue seleccionada para poder reanudarla.
    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)

        metadataTask?.cancel()
        metadataTask = nil
        metadataReader = nil

        nowPlaying = nil
    }

    /// Entra un título nuevo desde el stream.
    private func applyTitle(_ raw: String) {
        guard raw != nowPlaying else { return }

        nowPlaying = raw
        ticker.reset() // la marquesina empieza desde el principio
        updateTicker()

        // Muchas radios mandan "Artista - Canción" en un solo string.
        let parts = raw.components(separatedBy: " - ")
        let artist = parts.count > 1 ? parts[0] : "—"
        let song = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : raw

        print("[Riff] 🎧 Estación: \(currentStation?.displayName ?? "—") | Artista: \(artist) | Canción: \(song)")
    }

    // MARK: Persistencia

    private func save(_ station: Station) {
        guard let data = try? JSONEncoder().encode(station) else { return }
        defaults.set(data, forKey: Self.lastStationKey)
    }

    private static func loadLastStation(from defaults: UserDefaults) -> Station? {
        guard let data = defaults.data(forKey: lastStationKey) else { return nil }
        return try? JSONDecoder().decode(Station.self, from: data)
    }
}
