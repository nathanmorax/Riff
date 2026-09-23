//
//  MenuBarGlobe.swift
//  Riff
//
//  Created by Satori Tech 341 on 23/09/26.
//
import AppKit
import Observation

// MARK: - Globo animado para MenuBarExtra

/// Genera los cuadros del globo como imágenes template y publica el cuadro actual en `image`.
/// Úsalo en la etiqueta del MenuBarExtra: `Image(nsImage: globe.image)`.
@MainActor
@Observable
final class MenuBarGlobe {

    /// Cuadro actual. La etiqueta del MenuBarExtra se redibuja cuando cambia.
    private(set) var image: NSImage

    @ObservationIgnored private let frames: [NSImage]
    @ObservationIgnored private let idleImage: NSImage
    @ObservationIgnored private let fps: Double
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var index = 0

    /// - Parameters:
    ///   - pointSize: tamaño del ícono (16–18 pt es lo estándar en la barra)
    ///   - frameCount: cuadros por ciclo
    ///   - fps: velocidad; 12 es fluido sin gastar CPU
    ///   - latStep / lonStep: separación de la retícula en grados (menor = más puntos)
    ///   - dotRadius: radio de cada punto en pt
    init(pointSize: CGFloat = 17,
         frameCount: Int = 16,
         fps: Double = 12,
         latStep: Double = 20,
         lonStep: Double = 24,
         dotRadius: CGFloat = 0.72) {

        self.fps = fps

        let size = NSSize(width: pointSize, height: pointSize)

        // Basta girar `lonStep` grados: después la retícula se repite y el ciclo no salta.
        let frames = (0..<frameCount).map { i in
            MenuBarGlobe.makeImage(size: size,
                                   rotation: lonStep * Double(i) / Double(frameCount),
                                   latStep: latStep, lonStep: lonStep, dotRadius: dotRadius)
        }
        let idle = MenuBarGlobe.makeImage(size: size, rotation: 0,
                                          latStep: latStep, lonStep: lonStep, dotRadius: dotRadius)

        self.frames = frames
        self.idleImage = idle
        self.image = idle
    }

    // MARK: Control

    /// Empieza a girar.
    func start() {
        guard timer == nil else { return }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            image = idleImage
            return
        }

        let timer = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advance()
            }
        }
        // .common para que siga girando mientras el usuario tiene un menú abierto.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Se detiene y deja el globo quieto.
    func stop() {
        timer?.invalidate()
        timer = nil
        image = idleImage
    }

    /// Gira mientras `isPlaying` sea true y se detiene cuando sea false.
    /// Funciona con cualquier propiedad de un modelo @Observable, por ejemplo `{ player.isPlaying }`.
    func follow(_ isPlaying: @escaping @MainActor () -> Bool) {
        withObservationTracking {
            isPlaying() ? start() : stop()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.follow(isPlaying)
            }
        }
    }

    private func advance() {
        index = (index + 1) % frames.count
        image = frames[index]
    }

    // MARK: Dibujo

    private static func makeImage(size: NSSize, rotation: Double,
                                  latStep: Double, lonStep: Double, dotRadius: CGFloat) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            drawDots(in: rect, rotation: rotation, latStep: latStep, lonStep: lonStep, dotRadius: dotRadius)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func geometry(_ rect: NSRect, inset: CGFloat) -> (center: NSPoint, radius: CGFloat) {
        let radius = min(rect.width, rect.height) / 2 - inset
        return (NSPoint(x: rect.midX, y: rect.midY), radius)
    }

    /// Globo de puntos con inclinación. Los puntos del borde se hacen más chicos y tenues,
    /// así la esfera se lee con volumen aunque el ícono mida 16–18 pt.
    private static func drawDots(in rect: NSRect,
                                 rotation: Double,
                                 latStep: Double,
                                 lonStep: Double,
                                 dotRadius: CGFloat) {
        let (c, r) = geometry(rect, inset: dotRadius + 0.3)
        let tilt = -18.0 * .pi / 180

        var lat = -90.0 + latStep
        while lat < 90 {
            let p = lat * .pi / 180
            var lon = -180.0
            while lon < 180 {
                let l = (lon + rotation) * .pi / 180

                let x = cos(p) * sin(l)
                let y = sin(p)
                let z = cos(p) * cos(l)
                let y2 = y * cos(tilt) - z * sin(tilt)
                let z2 = y * sin(tilt) + z * cos(tilt)

                if z2 > 0.05 {
                    let pt = NSPoint(x: c.x + x * r, y: c.y + y2 * r)
                    let size = dotRadius * (0.55 + 0.45 * z2)
                    NSColor.black.withAlphaComponent(0.4 + 0.6 * z2).setFill()
                    NSBezierPath(ovalIn: NSRect(x: pt.x - size, y: pt.y - size,
                                                width: size * 2, height: size * 2)).fill()
                }
                lon += lonStep
            }
            lat += latStep
        }
    }
}
