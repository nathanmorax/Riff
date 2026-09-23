//
//  WaveIndicator.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

// MARK: - Indicador "sonando" (onda)

/// Línea que ondula con envolvente: firme en el centro y en calma en las orillas.
/// Se dibuja con el color de `foregroundStyle`.
struct WaveIndicator: View {

    var width: CGFloat = 22
    var height: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0.6 : context.date.timeIntervalSinceReferenceDate

            Canvas { ctx, size in
                let mid = size.height / 2
                let amplitude = size.height * 0.38
                var path = Path()

                for x in stride(from: 0.0, through: Double(size.width), by: 1) {
                    let envelope = sin(.pi * x / Double(size.width))
                    let wave = sin(x * 0.55 + t * 6) * 0.7 + sin(x * 1.3 - t * 9) * 0.3
                    let point = CGPoint(x: x, y: mid + envelope * amplitude * wave)
                    x == 0 ? path.move(to: point) : path.addLine(to: point)
                }

                ctx.stroke(path, with: .foreground,
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: width, height: height)
        .accessibilityLabel("Sonando")
    }
}
