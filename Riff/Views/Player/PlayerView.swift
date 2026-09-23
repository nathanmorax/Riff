//
//  PlayerView.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI
import AppKit

// MARK: - Reproductor compacto con recientes

struct PlayerView: View {

    let player: PlayerViewModel
    let search: SearchViewModel

    @FocusState private var fieldFocused: Bool
    @State private var hoveredRecent: String?
    @State private var panel = SearchPanelController()
    @State private var hostWindow = WindowBox()
    @State private var escapeMonitor = EscapeKeyMonitor()

    var body: some View {
        VStack(spacing: 0) {
            if let station = player.currentStation {
                nowPlaying(for: station)
                status
                recentsSection
                searchField
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            } else {
                emptyState
            }
        }
        .frame(width: 300)
        .background {
            // Clic en cualquier zona vacía del popover: quita el foco del campo y cierra la búsqueda.
            // En macOS esto no pasa solo; hacer clic en algo que no acepta foco no se lo quita al TextField.
            Color.black
                .contentShape(Rectangle())
                .onTapGesture {
                    fieldFocused = false
                    search.dismiss()
                }
        }
        .background(WindowReader { hostWindow.window = $0 })
        .background(commandFShortcut)
        .onChange(of: search.isPresented) { _, presented in
            if presented {
                showPanel()
            } else {
                panel.hide()
                fieldFocused = false
            }
        }
        .onAppear {
            escapeMonitor.start { event in
                handleEscape(event)
            }
        }
    }

    // MARK: Estación actual

    private func nowPlaying(for station: Station) -> some View {
        HStack(spacing: 11) {
            StationTile(station: station, size: 42)
                .id(station.id)
                .transition(.scale(scale: 0.9).combined(with: .opacity))

            VStack(alignment: .leading, spacing: 2) {
                Text(station.displayName)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)

                Text(subtitle(for: station))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .animation(.easeOut(duration: 0.25), value: player.nowPlaying)

            Spacer(minLength: 0)

            playButton
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .animation(.snappy(duration: 0.3), value: station.id)
    }

    private func subtitle(for station: Station) -> String {
        if let song = player.nowPlaying, !song.isEmpty { return song }
        return station.genres.isEmpty ? String(localized: "Radio en vivo") : station.genres.replacingOccurrences(of: " · ", with: ", ")
    }

    private var playButton: some View {
        Button {
            player.isActive ? player.stop() : player.play()
        } label: {
            Group {
                if player.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                } else if player.isPlaying {
                    Image(systemName: "stop.fill")
                } else {
                    Image(systemName: "play.fill")
                }
            }
            .frame(width: 14, height: 14) // mismo tamaño en los 3 estados
        }
        .buttonStyle(CompactPlayButtonStyle())
        .help(playButtonHelp)
    }

    // MARK: Estado (onda pequeña)

    private var status: some View {
        HStack(spacing: 6) {
            ZStack {
                if player.isPlaying {
                    WaveIndicator(width: 20, height: 12)
                        .transition(.opacity)
                } else {
                    Capsule()
                        .frame(width: 20, height: 1.5)
                        .transition(.opacity)
                }
            }
            .frame(width: 20, height: 12)
            .foregroundStyle(player.isPlaying ? Color.primary : Color.secondary.opacity(0.6))

            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(player.hasFailed ? Color.red : Color.secondary)
                .contentTransition(.opacity)

            Spacer(minLength: 0)

            quitButton
                .padding(.vertical, -6)  // el botón mide 24 pt; así la fila no crece
                .padding(.trailing, 4)   // centrado bajo el botón de play
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .animation(.easeOut(duration: 0.25), value: player.isPlaying)
        .animation(.easeOut(duration: 0.25), value: statusText)
    }

    // `String(localized:)`: `Text(unaVariable)` no se traduce solo, un literal sí.
    private var statusText: String {
        if player.hasFailed { return String(localized: "No se pudo conectar") }
        if player.isLoading { return String(localized: "Conectando…") }
        if player.isPlaying { return String(localized: "En vivo") }
        return String(localized: "Detenido")
    }

    private var playButtonHelp: String {
        if player.hasFailed { return String(localized: "Reintentar") }
        return player.isActive ? String(localized: "Detener") : String(localized: "Reproducir")
    }

    // MARK: Recientes

    @ViewBuilder
    private var recentsSection: some View {
        if !player.recents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recientes")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(hoveredRecent ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: 170, alignment: .trailing)
                }

                HStack(spacing: 8) {
                    ForEach(player.recents) { station in
                        RecentTile(
                            station: station,
                            isCurrent: station.id == player.currentStation?.id
                        ) {
                            player.play(station)
                        } onHover: { hovering in
                            if hovering {
                                hoveredRecent = station.displayName
                            } else if hoveredRecent == station.displayName {
                                hoveredRecent = nil
                            }
                        }
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.3), value: player.recents.map(\.id))
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }

    // MARK: Campo de búsqueda

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Buscar estación", text: Binding(
                get: { search.query },
                set: { search.query = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($fieldFocused)
            .onSubmit { search.playSelected() }
            .onKeyPress(.downArrow) {
                search.moveSelection(by: 1)
                return .handled
            }
            .onKeyPress(.upArrow) {
                search.moveSelection(by: -1)
                return .handled
            }

            if search.isPresented && !search.query.isEmpty {
                Button {
                    search.query = ""
                    fieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Borrar")
                .transition(.opacity)
            } else if !search.isPresented {
                Text(verbatim: "⌘F")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .frame(height: 18)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            Color.white.opacity(fieldFocused ? 0.12 : 0.08),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(fieldFocused ? 0.35 : 0), lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { openSearch() })
        .animation(.easeOut(duration: 0.15), value: fieldFocused)
        .animation(.easeOut(duration: 0.15), value: search.isPresented)
        .animation(.easeOut(duration: 0.15), value: search.query.isEmpty)
    }

    /// Botón invisible que solo existe para el atajo ⌘F.
    private var commandFShortcut: some View {
        Button("Buscar estación") {
            openSearch()
        }
        .keyboardShortcut("f", modifiers: .command)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: Primera vez (sin estación)

    private var emptyState: some View {
        VStack(spacing: 18) {
            LiveGlobeHeader(globeSize: 52)

            VStack(alignment: .leading, spacing: 6) {
                Text("Sintoniza")
                Text("algo nuevo.")
            }
            .foregroundStyle(.white)
            .font(.system(size: 28, weight: .heavy, design: .default))
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Busca por nombre o género y empieza a escuchar radio en vivo.")
                .font(.system(size: 12, weight: .heavy, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                if search.isPresented {
                    searchField
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    Button {
                        openSearch()
                    } label: {
                        HStack {
                            Text("Buscar estación")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                    .buttonStyle(PillButtonStyle())
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
                }
            }
            .animation(.snappy(duration: 0.25), value: search.isPresented)
        }
        .padding(20)
        .overlay(alignment: .topTrailing) {
            quitButton
                .padding(10)
        }
    }

    // MARK: Salir

    /// La app no tiene ícono en el Dock (`LSUIElement`), así que esta es la forma de cerrarla:
    /// una perilla que se gira hasta el tope. ⌘Q también funciona.
    private var quitButton: some View {
        OffKnob {
            NSApplication.shared.terminate(nil)
        }
        .background(quitShortcut)
    }

    /// Botón invisible que solo existe para el atajo ⌘Q.
    private var quitShortcut: some View {
        Button("Salir de Riff") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: Acciones

    private func openSearch() {
        search.present()
        // En el estado vacío el campo aparece en este mismo cambio; se enfoca en el siguiente ciclo.
        DispatchQueue.main.async {
            fieldFocused = true
        }
    }

    /// esc en dos niveles, como Spotlight: primero cierra la búsqueda, después el popover.
    /// Devuelve true si se usó la tecla (para que no siga a otra vista).
    private func handleEscape(_ event: NSEvent) -> Bool {
        guard let window = hostWindow.window, event.window === window else { return false }

        if search.isPresented {
            search.dismiss()
        } else {
            window.close()
        }
        return true
    }

    private func showPanel() {
        guard let window = hostWindow.window else { return }
        panel.show(below: window, onParentResign: { search.dismiss() }) {
            SearchResultsView(search: search, player: player)
        }
    }
}
