//
//  AVFoundation+Streams.swift
//  Riff
//
//  Created by Nathan Mora on 19/09/26.
//
@preconcurrency import AVFoundation

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


extension AVPlayerItem {

    /// `status` del item como AsyncStream. Sirve para saber cuándo un stream no carga (`.failed`).
    var statusStream: AsyncStream<AVPlayerItem.Status> {
        AsyncStream { continuation in
            let observation = observe(
                \.status,
                options: [.initial, .new]
            ) { item, _ in
                continuation.yield(item.status)
            }

            continuation.onTermination = { _ in
                observation.invalidate()
            }
        }
    }
}
