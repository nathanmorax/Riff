//
//  ButtonStyles.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

// MARK: - Estilos de botón

/// Botón circular de 32 pt, gris translúcido, con hover y press.
struct CompactPlayButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        CompactPlayButton(configuration: configuration)
    }

    private struct CompactPlayButton: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(isHovering ? 0.2 : 0.14), in: Circle())
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }
    }
}

/// Botón cápsula blanco: crece un poco al pasar el cursor y se encoge al presionar.
struct PillButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        PillButton(configuration: configuration)
    }

    private struct PillButton: View {

        let configuration: ButtonStyleConfiguration

        @State private var isHovering = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var scale: CGFloat {
            if configuration.isPressed { return 0.97 }
            return isHovering ? 1.03 : 1
        }

        var body: some View {
            configuration.label
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)
                .padding(.vertical, 13)
                .padding(.horizontal, 20)
                .background(Color.white, in: Capsule())
                .contentShape(Capsule())
                .scaleEffect(reduceMotion ? 1 : scale)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isHovering)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }
    }
}


// MARK: - Botón de ícono con hover

struct PanelIconButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        PanelIconButton(configuration: configuration)
    }

    private struct PanelIconButton: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .frame(width: 24, height: 24)
                .foregroundStyle(isHovering ? Color.primary : Color.secondary)
                .background(Color.white.opacity(isHovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
                .opacity(configuration.isPressed ? 0.7 : 1)
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .onHover { isHovering = $0 }
        }
    }
}
