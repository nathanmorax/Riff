//
//  OffKnob.swift
//  Riff
//
//  Created by Nathan Mora on 23/09/26.
//
import SwiftUI
import AppKit

// MARK: - Perilla de apagado

/// Perilla de radio para cerrar la app, como el interruptor de volumen de un radio antiguo:
/// se gira hacia la izquierda (arrastrando a la izquierda o hacia abajo) hasta el tope y "hace clic".
/// - Al pasar el cursor, gira un poco como pista.
/// - Si la sueltas antes del tope, regresa con un pequeño rebote.
/// - Un clic simple la gira sola hasta el final.
struct OffKnob: View {

    let onTurnOff: () -> Void

    /// Grados de giro hasta el tope (sentido antihorario).
    private let travel: Double = 130
    /// Puntos de arrastre para recorrer todo el giro.
    private let dragDistance: CGFloat = 36
    /// Giro de pista al pasar el cursor.
    private let hoverHint: Double = -20

    @State private var angle: Double = 0
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var isOff = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "dial.low")
            .font(.system(size: 13, weight: .medium))
            .rotationEffect(.degrees(displayAngle))
            .frame(width: 24, height: 24)
            .foregroundStyle(isActive ? Color.primary : Color.secondary)
            .background(Color.white.opacity(isActive ? 0.08 : 0), in: Circle())
            .contentShape(Circle())
            .onHover { hovering in
                withAnimation(.snappy(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .gesture(turnGesture)
            .help("Salir de Knob")
            .accessibilityElement()
            .accessibilityLabel("Salir de Knob")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { turnOff() }
    }

    private var isActive: Bool {
        isHovering || isDragging || isOff
    }

    /// Mientras se arrastra (o ya se apagó) manda el ángulo real; si no, solo la pista del hover.
    private var displayAngle: Double {
        if isDragging || isOff { return angle }
        return isHovering && !reduceMotion ? hoverHint : 0
    }

    // MARK: Gesto

    private var turnGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isOff else { return }
                isDragging = true

                // Izquierda o abajo = bajar la perilla. Derecha o arriba no la pasan de 0.
                let pull = max(0, -value.translation.width + value.translation.height)
                let progress = min(pull / dragDistance, 1)
                angle = -travel * progress

                if progress >= 1 {
                    turnOff()
                }
            }
            .onEnded { value in
                guard !isOff else { return }

                let moved = abs(value.translation.width) + abs(value.translation.height)
                if moved < 3 {
                    turnOff() // clic simple
                } else {
                    // No llegó al tope: regresa con rebote, como un resorte.
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                        angle = 0
                        isDragging = false
                    }
                }
            }
    }

    // MARK: Apagar

    private func turnOff() {
        guard !isOff else { return }
        isOff = true

        // El "clic" del interruptor, en trackpads con Force Touch.
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)

        withAnimation(.easeIn(duration: reduceMotion ? 0 : 0.2)) {
            angle = -travel
        }

        // Deja ver el giro completo antes de cerrar.
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.3)) {
            onTurnOff()
        }
    }
}

#Preview {
    OffKnob { }
        .padding(40)
        .background(Color.black)
}
