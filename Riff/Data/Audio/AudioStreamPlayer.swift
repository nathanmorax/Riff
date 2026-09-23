//
//  AudioStreamPlayer.swift
//  Riff
//
//  Created by Satori Tech 341 on 19/09/26.
//
@preconcurrency import AVFoundation

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

final class AudioStreamPlayer: AudioStreaming {

    let statusUpdates: AsyncStream<PlaybackStatus>
    let titleUpdates: AsyncStream<String>

    private let statusContinuation: AsyncStream<PlaybackStatus>.Continuation
    private let titleContinuation: AsyncStream<String>.Continuation

    private let player = AVPlayer()
    private var metadataReader: TimedMetadataReader?
    /// El item actual no pudo cargar. Se limpia con el siguiente `play` o `stop`.
    private var itemFailed = false

    // `nonisolated(unsafe)` para poder cancelarlos desde deinit. Solo se escriben en el MainActor.
    nonisolated(unsafe) private var controlTask: Task<Void, Never>?
    nonisolated(unsafe) private var itemTask: Task<Void, Never>?
    nonisolated(unsafe) private var metadataTask: Task<Void, Never>?

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
    }

    deinit {
        controlTask?.cancel()
        itemTask?.cancel()
        metadataTask?.cancel()
        statusContinuation.finish()
        titleContinuation.finish()
    }

    // MARK: Control

    func play(url: URL) {
        itemFailed = false

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

        // Si el stream no carga (URL caída, formato no soportado), el item pasa a `.failed`.
        let itemStatus = item.statusStream
        itemTask?.cancel()
        itemTask = Task { [weak self] in
            for await status in itemStatus where status == .failed {
                guard let self else { return }
                self.itemFailed = true
                self.statusContinuation.yield(.failed)
            }
        }

        player.replaceCurrentItem(with: item)
        player.play()
    }

    /// Detiene y suelta el item actual.
    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)

        itemTask?.cancel()
        itemTask = nil
        metadataTask?.cancel()
        metadataTask = nil
        metadataReader = nil

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
            statusContinuation.yield(.playing)
        case .waitingToPlayAtSpecifiedRate:
            statusContinuation.yield(.loading)
        case .paused:
            statusContinuation.yield(.stopped)
        @unknown default:
            statusContinuation.yield(.stopped)
        }
    }
}
