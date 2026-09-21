//
//  PlayerView.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

// MARK: - Mini reproductor (popover)

struct PlayerView: View {

    let radio: RadioPlayer

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            if let station = radio.currentStation {
                header(for: station)
                controls
            } else {
                emptyState
            }

            footer
        }
        .padding(14)
        .frame(width: 280)
    }

    // MARK: Con estación

    private func header(for station: Station) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: station.faviconURL) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Image(systemName: "radio")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(station.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        if radio.isLoading { return "Conectando…" }
        if radio.isPlaying { return radio.nowPlaying ?? "En vivo" }
        return "Detenida"
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                radio.play()
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(RoundButtonStyle(prominent: true))
            .disabled(radio.isActive)
            .help("Reproducir")

            Button {
                radio.stop()
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(RoundButtonStyle())
            .disabled(!radio.isActive)
            .help("Detener")
        }
    }

    // MARK: Primera vez (sin estación)

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)

            Text("Elige una estación")
                .font(.headline)

            Text("Busca por nombre o género para empezar a escuchar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                openSearch()
            } label: {
                Label("Buscar estación", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Pie

    private var footer: some View {
        HStack {
            Button {
                openSearch()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Buscar estación")

            Spacer()

            statusBadge

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Salir de Riff")
        }
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if radio.isPlaying {
            badge("EN VIVO", color: .red)
        } else if radio.isLoading {
            badge("CONECTANDO", color: .orange)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
        }
        .foregroundStyle(color)
    }

    private func openSearch() {
        openWindow(id: "search")
        NSApp.activate()
    }
}

/// Botón circular de 44 pt para Play y Stop.
private struct RoundButtonStyle: ButtonStyle {

    var prominent = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 44, height: 44)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(prominent ? Color.accentColor : Color.primary.opacity(0.10), in: Circle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}
