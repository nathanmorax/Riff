//
//  AudioStreamPlayer.swift
//  Riff
//
//  Created by Satori Tech 341 on 19/09/26.
//
import Foundation
@preconcurrency import AVFoundation
import Network

// MARK: - Estado de reproducción

/// Estado del reproductor, ya traducido desde AVPlayer.
enum PlaybackStatus: Equatable {
    case stopped
    case loading
    case playing
    case failed
}

// MARK: - Contrato

/// Reproduce un stream de audio y avisa su estado y los títulos que vienen dentro del stream.
/// `PlayerViewModel` depende de este protocolo, no de AVFoundation (se puede cambiar por un mock en tests).
protocol AudioStreaming: AnyObject {
    /// Cambios de estado. Un solo consumidor: el ViewModel dueño del reproductor.
    var statusUpdates: AsyncStream<PlaybackStatus> { get }
    /// Títulos en vivo ("Artista - Canción") de la estación que suena. Un solo consumidor.
    var titleUpdates: AsyncStream<String> { get }

    func play(url: URL)
    func stop()
}

// MARK: - Implementación con AVPlayer

/// Además de reproducir, se reconecta solo:
/// - Si el stream se cae (el item falla o "termina", cosa que en radio en vivo significa que se cortó),
///   reintenta con espera creciente: 2, 4, 8, 16 y 30 s. Mientras tanto la UI muestra "Conectando…".
/// - Si se agotan los intentos, queda en `.failed` ("No se pudo conectar").
/// - Cuando vuelve el internet, reintenta de inmediato aunque ya se hubiera rendido.
final class AudioStreamPlayer: AudioStreaming {

    let statusUpdates: AsyncStream<PlaybackStatus>
    let titleUpdates: AsyncStream<String>

    private let statusContinuation: AsyncStream<PlaybackStatus>.Continuation
    private let titleContinuation: AsyncStream<String>.Continuation

    private let player = AVPlayer()
    private var metadataReader: TimedMetadataReader?

    // MARK: Reconexión

    /// Esperas entre intentos; su cantidad es el máximo de intentos seguidos.
    private let retryDelays: [Duration] = [.seconds(2), .seconds(4), .seconds(8), .seconds(16), .seconds(30)]

    /// Stream que el usuario pidió escuchar. Se mantiene durante los reintentos.
    private var currentURL: URL?
    /// El usuario quiere que suene (se apaga solo con `stop()`).
    private var wantsToPlay = false
    /// Se perdió la conexión y estamos intentando volver; termina al sonar de nuevo o al rendirse.
    private var isReconnecting = false
    private var retryAttempt = 0
    /// Se agotaron los intentos. Se limpia con el siguiente `play`, `stop` o al volver la red.
    private var itemFailed = false

    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true

    // `nonisolated(unsafe)` para poder cancelarlos desde deinit. Solo se escriben en el MainActor.
    nonisolated(unsafe) private var controlTask: Task<Void, Never>?
    nonisolated(unsafe) private var itemTasks: [Task<Void, Never>] = []
    nonisolated(unsafe) private var metadataTask: Task<Void, Never>?
    nonisolated(unsafe) private var retryTask: Task<Void, Never>?

    init() {
        let (status, statusContinuation) = AsyncStream.makeStream(of: PlaybackStatus.self)
        let (titles, titleContinuation) = AsyncStream.makeStream(of: String.self)
        self.statusUpdates = status
        self.statusContinuation = statusContinuation
        self.titleUpdates = titles
        self.titleContinuation = titleContinuation

        let stream = player.timeControlStatusStream

        controlTask = Task { [weak self] in
            for await status in stream {
                guard let self else { return }
                self.handle(status)
            }
        }

        // Se entrega en la cola principal (`start(queue: .main)`), así que ya estamos en el MainActor.
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            MainActor.assumeIsolated {
                self?.networkDidChange(isAvailable: isAvailable)
            }
        }
        networkMonitor.start(queue: .main)
    }

    deinit {
        controlTask?.cancel()
        itemTasks.forEach { $0.cancel() }
        metadataTask?.cancel()
        retryTask?.cancel()
        networkMonitor.cancel()
        statusContinuation.finish()
        titleContinuation.finish()
    }

    // MARK: Control

    func play(url: URL) {
        currentURL = url
        wantsToPlay = true
        resetReconnection()
        startItem(url)
    }

    /// Detiene y suelta el item actual. También cancela cualquier reconexión pendiente.
    func stop() {
        wantsToPlay = false
        resetReconnection()

        player.pause()
        player.replaceCurrentItem(with: nil)

        itemTasks.forEach { $0.cancel() }
        itemTasks = []
        metadataTask?.cancel()
        metadataTask = nil
        metadataReader = nil
    }

    // MARK: Item

    private func startItem(_ url: URL) {
        let item = AVPlayerItem(url: url)

        // Metadata dentro del stream: si la estación manda el título, llega aquí.
        // Un `AVPlayerItemMetadataOutput` solo se puede añadir a un item, así que hay uno por estación.
        let reader = TimedMetadataReader()
        item.add(reader.output)
        metadataReader = reader

        let titles = reader.titles
        let titleContinuation = self.titleContinuation
        metadataTask?.cancel()
        metadataTask = Task {
            for await title in titles {
                titleContinuation.yield(title)
            }
        }

        // Señales de que se cortó: el item no carga, falla a medio camino o "termina".
        itemTasks.forEach { $0.cancel() }
        itemTasks = [
            Task { [weak self] in
                for await status in item.statusStream where status == .failed {
                    self?.connectionLost()
                    return
                }
            },
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: AVPlayerItem.failedToPlayToEndTimeNotification, object: item) {
                    self?.connectionLost()
                    return
                }
            },
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: AVPlayerItem.didPlayToEndTimeNotification, object: item) {
                    self?.connectionLost()
                    return
                }
            }
        ]

        player.replaceCurrentItem(with: item)
        player.play()
    }

    // MARK: Reconexión

    private func connectionLost() {
        guard wantsToPlay, let url = currentURL, retryTask == nil else { return }

        guard retryAttempt < retryDelays.count else {
            giveUp()
            return
        }

        let delay = retryDelays[retryAttempt]
        retryAttempt += 1
        isReconnecting = true
        statusContinuation.yield(.loading)

        #if DEBUG
        print("[Knob] 🔌 Se cortó el stream. Reintento \(retryAttempt) de \(retryDelays.count) en \(delay)")
        #endif

        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.retryTask = nil

            // Sin internet no tiene caso intentar: esperamos a que vuelva la red.
            guard self.isNetworkAvailable else { return }
            self.startItem(url)
        }
    }

    private func giveUp() {
        isReconnecting = false
        itemFailed = true
        player.pause()
        statusContinuation.yield(.failed)
    }

    private func networkDidChange(isAvailable: Bool) {
        let cameBack = isAvailable && !isNetworkAvailable
        isNetworkAvailable = isAvailable

        // Volvió el internet y se había cortado (o ya nos habíamos rendido): intento inmediato.
        guard cameBack, wantsToPlay, isReconnecting || itemFailed, let url = currentURL else { return }

        #if DEBUG
        print("[Knob] 🌐 Volvió la red. Reconectando…")
        #endif

        resetReconnection()
        isReconnecting = true
        statusContinuation.yield(.loading)
        startItem(url)
    }

    private func resetReconnection() {
        retryTask?.cancel()
        retryTask = nil
        retryAttempt = 0
        isReconnecting = false
        itemFailed = false
    }

    // MARK: AVPlayer → PlaybackStatus

    private func handle(_ status: AVPlayer.TimeControlStatus) {
        guard !itemFailed else {
            statusContinuation.yield(.failed)
            return
        }

        switch status {
        case .playing:
            // Volvió a sonar: la reconexión (si la había) terminó bien.
            retryAttempt = 0
            isReconnecting = false
            statusContinuation.yield(.playing)
        case .waitingToPlayAtSpecifiedRate:
            statusContinuation.yield(.loading)
        case .paused:
            // Pausado por un corte, no por el usuario: seguimos mostrando "Conectando…".
            statusContinuation.yield(isReconnecting ? .loading : .stopped)
        @unknown default:
            statusContinuation.yield(.stopped)
        }
    }
}
