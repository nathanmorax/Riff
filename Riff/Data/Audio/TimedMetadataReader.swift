//
//  TimedMetadataReader.swift
//  Riff
//
//  Created by Satori Tech 341 on 19/09/26.
//
@preconcurrency import AVFoundation

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
                #if DEBUG
                print("[Riff] 🎵 metadata [\(item.identifier?.rawValue ?? "sin identificador")] = \(value ?? "nil")")
                #endif

                guard let identifier = item.identifier,
                      Self.titleIdentifiers.contains(identifier),
                      let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !clean.isEmpty else { return }

                continuation.yield(clean)
            }
        }
    }
}
