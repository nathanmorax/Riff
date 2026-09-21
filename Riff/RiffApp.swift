//
//  RiffApp.swift
//  Riff
//
//  Created by Satori Tech 341 on 19/09/26.
//
import SwiftUI

@main
struct RiffApp: App {

    @State private var radio = RadioPlayer()

    var body: some Scene {
        MenuBarExtra {
            ContentView1(radio: radio)
        } label: {
            MenuBarLabel(radio: radio)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Lo que se ve en la barra de menú:  ((•)) Jazz FM ●
struct MenuBarLabel: View {

    let radio: RadioPlayer

    /// true: muestra el título de la canción cuando la estación lo manda.
    /// false: siempre muestra el nombre de la estación.
    var showsSongTitle = true

    /// Caracteres máximos del texto antes de cortarlo con "…".
    var maxCharacters = 24

    var body: some View {
        if let station = radio.currentStation {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")

                Text(title(for: station))

                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(indicatorColor)
            }
        } else {
            Image(systemName: "dot.radiowaves.left.and.right")
        }
    }

    private func title(for station: Station) -> String {
        let text = showsSongTitle ? (radio.nowPlaying ?? station.displayName) : station.displayName
        guard text.count > maxCharacters else { return text }

        return String(text.prefix(maxCharacters - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Verde sonando, naranja cargando, gris si el stream se detuvo o falló.
    private var indicatorColor: Color {
        if radio.isPlaying { return .green }
        if radio.isLoading { return .orange }
        return .gray
    }
}
