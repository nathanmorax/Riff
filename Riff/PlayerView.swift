//
//  PlayerView.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

// MARK: - Mini reproductor

struct PlayerView: View {

    let radio: RadioPlayer
    let onSearch: () -> Void

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
        .background(Color.themeBackground)
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
                    .foregroundStyle(radio.hasFailed ? .red : .colorLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        if radio.hasFailed { return "No se pudo conectar" }
        if radio.isLoading { return "Connecting…" }
        if radio.isPlaying { return radio.nowPlaying ?? "LIVE" }
        return "Paused"
    }

    private var controls: some View {
        Button {
            radio.isActive ? radio.stop() : radio.play()
        } label: {
            Group {
                if radio.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if radio.isPlaying {
                    Image(systemName: "stop.fill")
                } else {
                    Image(systemName: "play.fill")
                }
            }
            .frame(width: 18, height: 18) // mismo tamaño en los 3 estados, para que el botón no cambie de forma
        }
        .buttonStyle(PlayStopButtonStyle())
        .help(radio.hasFailed ? "Reintentar" : radio.isActive ? "Detener" : "Reproducir")
    }
    
    /// Botón circular de 44 pt, único, que alterna entre Play, cargando y Stop.
    private struct PlayStopButtonStyle: ButtonStyle {

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(.white)
                .background(Color.colorGray, in: Circle())
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }

    // MARK: Primera vez (sin estación)

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)

            Text("Choose a station")
                .font(.headline)

            Text("Search by name or genre to start listening.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onSearch()
            } label: {
                Label("Find a station", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Pie

    // MARK: Pie

    private var footer: some View {
        HStack {
            if radio.currentStation != nil {
                Button {
                    onSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white)
                .help("Buscar estación")
            }

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
            .contextMenu {
                Button("Olvidar estación (debug)", role: .destructive) {
                    radio.forgetStation()
                }
            }
        }
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if radio.hasFailed {
            badge("CONNECTION FAILED", color: .red)
        } else if radio.isPlaying {
            badge("LIVE", color: .red)
        } else if radio.isLoading {
            badge("Connecting..", color: .orange)
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
            .background(prominent ? Color.colorGray : Color.colorGray, in: Circle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}
