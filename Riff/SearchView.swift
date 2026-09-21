//
//  SearchView.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

// MARK: - Búsqueda (ventana flotante)

struct SearchView: View {

    let radio: RadioPlayer

    @Environment(\.dismissWindow) private var dismissWindow
    @FocusState private var fieldFocused: Bool

    @State private var stations: [Station] = []
    @State private var isSearching = false
    @State private var query = ""
    @State private var selection: Station.ID?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            results
            Divider()
            hints
        }
        .frame(width: 360, height: 440)
        .background(SearchWindowConfigurator { close() })
        .task(id: trimmedQuery) {
            await search(trimmedQuery)
        }
        .onAppear {
            fieldFocused = true
        }
        .onExitCommand {
            close()
        }
    }

    // MARK: Piezas

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Nombre o género…", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($fieldFocused)
                .onSubmit { playSelected() }
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(stations) { station in
                        Button {
                            choose(station)
                        } label: {
                            SearchRow(station: station, isSelected: station.id == selection)
                        }
                        .buttonStyle(.plain)
                        .id(station.id)
                    }
                }
                .padding(6)
            }
            .onChange(of: selection) { _, id in
                if let id {
                    proxy.scrollTo(id)
                }
            }
        }
        .overlay {
            if stations.isEmpty {
                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Sin resultados")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var hints: some View {
        HStack(spacing: 14) {
            Text("↑↓ navegar")
            Text("↵ reproducir")
            Text("esc cerrar")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Acciones

    private func moveSelection(by delta: Int) {
        guard !stations.isEmpty else { return }

        let current = stations.firstIndex { $0.id == selection } ?? -1
        let next = min(max(current + delta, 0), stations.count - 1)
        selection = stations[next].id
    }

    private func playSelected() {
        guard let station = stations.first(where: { $0.id == selection }) ?? stations.first else { return }
        choose(station)
    }

    private func choose(_ station: Station) {
        radio.play(station)
        close()
    }

    private func close() {
        dismissWindow(id: "search")
    }

    // MARK: Búsqueda

    private func search(_ query: String) async {
        isSearching = true

        // Debounce: si el usuario sigue escribiendo, SwiftUI cancela este task
        // y arranca otro, así que el sleep se interrumpe y no llega la petición.
        if !query.isEmpty {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
        }

        do {
            let result = try await RadioAPI.stations(matching: query)
            guard !Task.isCancelled else { return }
            stations = result
            selection = result.first?.id
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            print("[Riff] ❌ Error de búsqueda: \(error)")
            stations = []
            selection = nil
        }

        isSearching = false
    }
}
