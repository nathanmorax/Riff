//
//  NowPlayingController.swift
//  Riff
//
//  Created by Satori Tech 341 on 24/09/26.
//
import Foundation
import MediaPlayer
import Observation

// MARK: - Reproduciendo ahora + teclas de medios

/// Conecta el reproductor con macOS:
/// - "Reproduciendo ahora" en el Centro de control: estación, canción y estado en vivo.
/// - Teclas de medios (⏯ del teclado, AirPods, Touch Bar): reproducir, detener y alternar.
/// Observa `PlayerViewModel` y le manda las órdenes; no sabe nada de AVFoundation.
@MainActor
final class NowPlayingController {

    private let player: PlayerViewModel
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commands = MPRemoteCommandCenter.shared()

    init(player: PlayerViewModel) {
        self.player = player
        registerCommands()
        observePlayer()
    }

    // MARK: Teclas de medios

    private func registerCommands() {
        // En radio en vivo "pausa" = detener: no se puede reanudar donde se quedó.
        commands.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.play() ?? .commandFailed }
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() ?? .commandFailed }
        }
        commands.stopCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() ?? .commandFailed }
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return .commandFailed }
                return self.player.isActive ? self.stop() : self.play()
            }
        }

        // Sin sentido en un stream en vivo: se desactivan para que macOS no los muestre.
        for command in [commands.nextTrackCommand, commands.previousTrackCommand,
                        commands.skipForwardCommand, commands.skipBackwardCommand,
                        commands.seekForwardCommand, commands.seekBackwardCommand] {
            command.isEnabled = false
        }
        commands.changePlaybackPositionCommand.isEnabled = false
    }

    private func play() -> MPRemoteCommandHandlerStatus {
        guard player.currentStation != nil else { return .noActionableNowPlayingItem }
        player.play()
        return .success
    }

    private func stop() -> MPRemoteCommandHandlerStatus {
        player.stop()
        return .success
    }

    // MARK: Info

    /// Vuelve a publicar la info cada vez que cambia algo que lee `update()`.
    private func observePlayer() {
        withObservationTracking {
            update()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observePlayer()
            }
        }
    }

    private func update() {
        guard let station = player.currentStation else {
            infoCenter.nowPlayingInfo = nil
            infoCenter.playbackState = .stopped
            return
        }

        // Muchas radios mandan "Artista - Canción": la canción va de título y el artista debajo.
        var title = station.displayName
        var artist = station.genres.isEmpty ? String(localized: "Radio en vivo") : station.genres
        if let song = player.nowPlaying, !song.isEmpty {
            let parts = song.components(separatedBy: " - ")
            if parts.count > 1 {
                artist = parts[0]
                title = parts.dropFirst().joined(separator: " - ")
            } else {
                title = song
                artist = station.displayName
            }
        }

        infoCenter.nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: station.displayName,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0
        ]

        // En macOS, `playbackState` decide a qué app le llegan las teclas de medios.
        if player.isActive {
            infoCenter.playbackState = .playing
        } else if player.hasFailed {
            infoCenter.playbackState = .interrupted
        } else {
            infoCenter.playbackState = .paused
        }
    }
}
