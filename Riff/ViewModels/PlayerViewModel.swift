//
//  PlayerViewModel.swift
//  Riff
//
//  Created by Satori Tech 341 on 23/09/26.
//
import Foundation
import Observation

// MARK: - ViewModel del reproductor

/// Estado que ve la UI: estación actual, título en vivo, estado de conexión y recientes.
/// No conoce AVFoundation ni UserDefaults: habla con `AudioStreaming` y `LibraryRepository`.
@MainActor
@Observable
final class PlayerViewModel {

    /// Estación seleccionada: la que suena o la última que se escuchó.
    /// Se recuerda entre lanzamientos; es `nil` solo la primera vez.
    private(set) var currentStation: Station?
    /// Título que manda el stream, si lo manda.
    private(set) var nowPlaying: String?
    private(set) var status: PlaybackStatus = .stopped
    /// Últimas estaciones reproducidas, la más reciente primero.
    private(set) var recents: [Station]

    var isPlaying: Bool { status == .playing }
    var isLoading: Bool { status == .loading }
    var hasFailed: Bool { status == .failed }

    /// Sonando o conectando.
    var isActive: Bool {
        isPlaying || isLoading
    }

    @ObservationIgnored private let audio: any AudioStreaming
    @ObservationIgnored private let library: any LibraryRepository
    /// Opcional: solo se usa para avisarle a radio-browser que se escuchó una estación.
    @ObservationIgnored private let stations: (any StationRepository)?

    // `nonisolated(unsafe)` para poder cancelarlos desde deinit. Solo se escriben en el MainActor.
    @ObservationIgnored nonisolated(unsafe) private var statusTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var titleTask: Task<Void, Never>?

    init(audio: any AudioStreaming, library: any LibraryRepository, stations: (any StationRepository)? = nil) {
        self.audio = audio
        self.library = library
        self.stations = stations
        self.currentStation = library.lastStation
        self.recents = library.recentStations

        let statusUpdates = audio.statusUpdates
        statusTask = Task { [weak self] in
            for await status in statusUpdates {
                guard let self else { return }
                self.status = status
            }
        }

        let titleUpdates = audio.titleUpdates
        titleTask = Task { [weak self] in
            for await title in titleUpdates {
                guard let self else { return }
                self.applyTitle(title)
            }
        }
    }

    deinit {
        statusTask?.cancel()
        titleTask?.cancel()
    }

    // MARK: Control

    /// Reanuda la estación seleccionada (la última que se escuchó). También sirve para reintentar.
    func play() {
        guard let station = currentStation, !isActive else { return }
        play(station)
    }

    /// Reproduce `station`, la recuerda como última y la sube a recientes.
    func play(_ station: Station) {
        guard let url = URL(string: station.urlResolved) else {
            #if DEBUG
            print("[Knob] ❌ URL inválida: \(station.urlResolved)")
            #endif
            return
        }

        #if DEBUG
        print("[Knob] ▶️ Reproduciendo: \(station.displayName)")
        #endif

        currentStation = station
        nowPlaying = nil

        library.recordPlayback(of: station)
        recents = library.recentStations

        audio.play(url: url)

        // Suma la escucha en radio-browser, sin esperar ni bloquear la reproducción.
        if let stations {
            Task {
                await stations.registerPlay(of: station)
            }
        }
    }

    /// Detiene la reproducción. La estación sigue seleccionada para poder reanudarla.
    func stop() {
        audio.stop()
        nowPlaying = nil
    }

    // MARK: Metadata

    private func applyTitle(_ title: String) {
        guard title != nowPlaying else { return }
        nowPlaying = title
    }
}
