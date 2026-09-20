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

// MARK: - Menu bar animation

/// Animaciones para la barra de menú. La etiqueta de un `MenuBarExtra` no anima
/// con SwiftUI, así que cada estilo devuelve un texto distinto según el `tick`
/// (que avanza cada 150 ms) y la vista se vuelve a dibujar cuadro por cuadro.
enum MenuBarAnimation {
    case equalizer   // ▂▅▇▅
    case dancer      // 🕺 💃
    case disco       // 🕺 🪩 💃 🪩
    case kaomoji     // ┏(・o･)┛♪ ┗(・o･)┓♪

    func frame(at tick: Int) -> String {
        switch self {

        case .equalizer:
            let levels = Array("▁▂▃▄▅▆▇█")
            let pattern = [1, 3, 5, 7, 5, 3]

            // Cuatro barras que suben y bajan desfasadas.
            return String((0..<4).map { bar in
                levels[pattern[(tick + bar * 5) % pattern.count]]
            })

        case .dancer:
            return Self.cycle(["🕺", "💃"], tick: tick, every: 3)

        case .disco:
            return Self.cycle(["🕺", "🪩", "💃", "🪩"], tick: tick, every: 3)

        case .kaomoji:
            return Self.cycle(["┏(・o･)┛♪", "┗(・o･)┓♪"], tick: tick, every: 3)
        }
    }

    /// Cambia de cuadro cada `every` ticks (3 ticks = 450 ms).
    private static func cycle(_ frames: [String], tick: Int, every: Int) -> String {
        frames[(tick / every) % frames.count]
    }
}

// MARK: - Player

@MainActor
@Observable
final class RadioPlayer {

    private(set) var currentStation: Station?
    private(set) var nowPlaying: String?
    private(set) var isPlaying = false
    private(set) var isLoading = false

    /// Contador que avanza cada 150 ms mientras suena algo; mueve la animación y la marquesina.
    private(set) var animationFrame = 0

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var metadataReader: TimedMetadataReader?

    // `nonisolated(unsafe)` para poder cancelarlos desde deinit. Solo se escriben en el MainActor.
    @ObservationIgnored nonisolated(unsafe) private var statusTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var metadataTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var tickerTask: Task<Void, Never>?

    init() {
        let stream = player.timeControlStatusStream

        statusTask = Task { [weak self] in
            for await status in stream {
                guard let self else { return }
                self.isPlaying = (status == .playing)
                self.isLoading = (status == .waitingToPlayAtSpecifiedRate)

                if self.isPlaying {
                    self.startTicker()
                } else {
                    self.stopTicker()
                }
            }
        }
    }

    deinit {
        statusTask?.cancel()
        metadataTask?.cancel()
        tickerTask?.cancel()
    }

    // MARK: Menu bar

    /// Cambia esta línea para elegir la animación: .equalizer, .dancer, .disco o .kaomoji
    private static let animation: MenuBarAnimation = .equalizer

    private static let visibleWidth = 22 // caracteres visibles del texto; ajústalo a tu gusto

    /// Texto completo para la barra de menú: animación + título (o nombre de la estación) con marquesina.
    var menuBarText: String {
        let title = nowPlaying ?? currentStation?.displayName ?? ""
        let scrolling = Self.marquee(title, step: 5, width: Self.visibleWidth)
        return "\(Self.animation.frame(at: animationFrame)) \(scrolling)"
    }

    /// Si el texto cabe, lo devuelve tal cual; si no, devuelve una ventana que se desplaza en bucle.
    private static func marquee(_ text: String, step: Int, width: Int) -> String {
        let chars = Array(text)
        guard chars.count > width else { return text }

        let looped = chars + Array("   •   ")
        let start = step % looped.count

        return String((0..<width).map { looped[(start + $0) % looped.count] })
    }

    // MARK: Ticker

    private func startTicker() {
        guard tickerTask == nil else { return }

        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled, let self else { return }
                self.animationFrame &+= 1
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    // MARK: Control

    /// Si tocas la estación que está sonando, se detiene. Si tocas otra, cambia.
    func toggle(_ station: Station) {
        if currentStation?.id == station.id && (isPlaying || isLoading) {
            stop()
        } else {
            play(station)
        }
    }

    func isCurrent(_ station: Station) -> Bool {
        currentStation?.id == station.id
    }

    private func play(_ station: Station) {
        guard let url = URL(string: station.urlResolved) else {
            print("[Riff] ❌ URL inválida: \(station.urlResolved)")
            return
        }

        print("[Riff] ▶️ Reproduciendo: \(station.displayName)")

        currentStation = station
        nowPlaying = nil
        animationFrame = 0

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

    private func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)

        metadataTask?.cancel()
        metadataTask = nil
        metadataReader = nil

        currentStation = nil
        nowPlaying = nil
    }

    /// Entra un título nuevo desde el stream.
    private func applyTitle(_ raw: String) {
        guard raw != nowPlaying else { return }

        nowPlaying = raw
        animationFrame = 0 // la marquesina empieza desde el principio

        // Muchas radios mandan "Artista - Canción" en un solo string.
        let parts = raw.components(separatedBy: " - ")
        let artist = parts.count > 1 ? parts[0] : "—"
        let song = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : raw

        print("[Riff] 🎧 Estación: \(currentStation?.displayName ?? "—") | Artista: \(artist) | Canción: \(song)")
    }
}

// MARK: - View

struct ContentView1: View {

    let radio: RadioPlayer

    @State private var stations: [Station] = []
    @State private var isSearching = false
    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

//            Text("Radio")
//                .foregroundStyle(.secondary)

            TextField("Buscar estación o género…", text: $query)
                .textFieldStyle(.roundedBorder)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {

                    ForEach(stations) { station in

                        Button {
                            radio.toggle(station)
                        } label: {
                            HStack(spacing: 10) {

                                AsyncImage(url: station.faviconURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    Image(systemName: "radio")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 24, height: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.displayName)
                                        .lineLimit(1)
                                        .foregroundStyle(radio.isCurrent(station) ? Color.accentColor : .primary)

                                    if radio.isCurrent(station), let title = radio.nowPlaying {
                                        Text(title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer(minLength: 0)

                                if radio.isCurrent(station) {
                                    if radio.isLoading {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else if radio.isPlaying {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(station.name)

                        Divider()
                    }
                }
            }
            .overlay {
                if stations.isEmpty {
                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Sin resultados")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            
            HStack {
                
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")

                }

            }
        }
        .padding()
        .frame(width: 280, height: 330)
        .task(id: trimmedQuery) {
            await search(trimmedQuery)
        }
    }

    // MARK: - Search

    private func search(_ query: String) async {
        isSearching = true

        // Debounce: si el usuario sigue escribiendo, SwiftUI cancela este task
        // y arranca otro, así que el sleep se interrumpe y no llega la petición.
        if !query.isEmpty {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
        }

        do {
            let result = try await RadioAPI.stations(matching: query)
            guard !Task.isCancelled else { return }
            stations = result
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            print("[Riff] ❌ Error de búsqueda: \(error)")
            stations = []
        }

        isSearching = false
    }
}
