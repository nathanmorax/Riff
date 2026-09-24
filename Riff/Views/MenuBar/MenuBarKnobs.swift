//
//  MenuBarKnobs.swift
//  Riff
//
//  Created by Nathan Mora on 24/09/26.
//
import AppKit
import Observation

// MARK: - Dos perillas para el MenuBarExtra

/// El ícono de la app ("Dos perillas") en versión de barra de menú.
/// Genera los cuadros como imágenes template (macOS las pinta blancas o negras según la barra)
/// y publica el cuadro actual en `image`. Úsalo así: `Image(nsImage: menuBarIcon.image)`.
///
/// Animación mientras suena: las perillas se mueven solas, como si alguien estuviera sintonizando.
/// - Izquierda (sintonía): barre de un lado a otro, amplio y lento.
/// - Derecha (volumen): se mece poco, a otro ritmo.
/// En pausa o sin estación se quedan quietas en su posición de reposo, igual que en el ícono de la app.
@MainActor
@Observable
final class MenuBarKnobs {

    /// Cuadro actual. La etiqueta del MenuBarExtra se redibuja cuando cambia.
    private(set) var image: NSImage

    @ObservationIgnored private let frames: [NSImage]
    @ObservationIgnored private let idleImage: NSImage
    @ObservationIgnored private let fps: Double
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var index = 0

    // Posición de reposo, igual que en el ícono de la app (grados, 0 = arriba).
    private static let restLeft = -50.0
    private static let restRight = 40.0

    /// - Parameters:
    ///   - height: alto del ícono (16–18 pt es lo estándar en la barra)
    ///   - frameCount: cuadros por ciclo; con 12 fps, 36 cuadros = un ciclo de 3 s
    ///   - fps: velocidad; 12 es fluido sin gastar CPU
    init(height: CGFloat = 16, frameCount: Int = 36, fps: Double = 12) {
        self.fps = fps

        // Dos círculos lado a lado con aire entre ellos: el ancho sale del diámetro y la separación,
        // así nunca se enciman.
        let diameter = (height * 0.8).rounded()          // 13 pt con alto 16
        let gap = (height * 0.25).rounded()              // 4 pt con alto 16
        let size = NSSize(width: diameter * 2 + gap + 2, height: height)

        let frames = (0..<frameCount).map { i in
            let t = Double(i) / Double(frameCount) * 2 * .pi
            // Sintonía: barrido amplio. Volumen: vaivén corto al doble de velocidad, desfasado.
            let left = Self.restLeft + 45 * sin(t)
            let right = Self.restRight + 18 * sin(2 * t + .pi / 3)
            return MenuBarKnobs.makeImage(size: size, diameter: diameter, gap: gap, left: left, right: right)
        }
        let idle = MenuBarKnobs.makeImage(size: size, diameter: diameter, gap: gap,
                                          left: Self.restLeft, right: Self.restRight)

        self.frames = frames
        self.idleImage = idle
        self.image = idle
    }

    // MARK: Control

    /// Empieza a animarse.
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
        // .common para que siga moviéndose mientras el usuario tiene un menú abierto.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Se detiene y deja las perillas en reposo.
    func stop() {
        timer?.invalidate()
        timer = nil
        index = 0
        image = idleImage
    }

    /// Se anima mientras `isPlaying` sea true y se detiene cuando sea false.
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

    private static func makeImage(size: NSSize, diameter: CGFloat, gap: CGFloat,
                                  left: Double, right: Double) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let radius = diameter / 2
            let leftCenter = NSPoint(x: rect.minX + 1 + radius, y: rect.midY)
            let rightCenter = NSPoint(x: leftCenter.x + diameter + gap, y: rect.midY)

            drawKnob(center: leftCenter, radius: radius, angle: left)
            drawKnob(center: rightCenter, radius: radius, angle: right)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Disco lleno con la marca "recortada" (transparente), como en el ícono de la app.
    private static func drawKnob(center: NSPoint, radius: CGFloat, angle: Double) {
        guard let context = NSGraphicsContext.current else { return }

        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                    width: radius * 2, height: radius * 2)).fill()

        // 0° = arriba, positivo = a la derecha (en AppKit la y crece hacia arriba).
        let a = angle * .pi / 180
        let from = NSPoint(x: center.x + sin(a) * radius * 0.22, y: center.y + cos(a) * radius * 0.22)
        let to = NSPoint(x: center.x + sin(a) * radius * 0.74, y: center.y + cos(a) * radius * 0.74)

        let mark = NSBezierPath()
        mark.move(to: from)
        mark.line(to: to)
        mark.lineWidth = max(1.4, radius * 0.26)
        mark.lineCapStyle = .round

        context.saveGraphicsState()
        context.compositingOperation = .clear
        mark.stroke()
        context.restoreGraphicsState()
    }
}
