//
//  SearchResultsView.swift
//  Riff
//
//  Created by Nathan Mora on 23/09/26.
//
import SwiftUI

// MARK: - Resultados (contenido del panel)

struct SearchResultsView: View {

    let search: SearchViewModel
    let player: PlayerViewModel
    /// Solo para exportar capturas: lista fija en lugar de ScrollView (ImageRenderer no dibuja NSScrollView).
    var isSnapshot = false

    @Namespace private var highlight

    var body: some View {
        VStack(spacing: 0) {
            header
            if isSnapshot {
                snapshotList
            } else {
                results
            }
            Divider()
            hints
        }
    }

    private var header: some View {
        HStack {
            Text(headerText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            Spacer()

            Button {
                search.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(PanelIconButtonStyle())
            .help("Cerrar búsqueda")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .animation(.easeOut(duration: 0.15), value: headerText)
    }

    private var headerText: String {
        if search.isSearching && search.stations.isEmpty { return String(localized: "Buscando…") }
        if search.trimmedQuery.isEmpty { return String(localized: "Populares") }
        // Singular/plural por idioma en Localizable.xcstrings ("1 estación", "20 estaciones").
        return String(localized: "\(search.stations.count) estaciones")
    }

    /// Las primeras filas, sin scroll. Mismo espaciado que `results`.
    private var snapshotList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(search.stations.prefix(6)) { station in
                SearchRow(
                    station: station,
                    isSelected: station.id == search.selection,
                    isPlaying: player.isPlaying && player.currentStation?.id == station.id,
                    highlight: highlight
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
        .clipped()
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(search.stations) { station in
                        Button {
                            search.play(station)
                        } label: {
                            SearchRow(
                                station: station,
                                isSelected: station.id == search.selection,
                                isPlaying: player.isPlaying && player.currentStation?.id == station.id,
                                highlight: highlight
                            )
                        }
                        .buttonStyle(.plain)
                        .id(station.id)
                        .onHover { hovering in
                            if hovering { search.select(station.id) }
                        }
                        .transition(.opacity.combined(with: .offset(y: 3)))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
            .onChange(of: search.selection) { _, id in
                guard let id else { return }
                withAnimation(.snappy(duration: 0.18)) {
                    proxy.scrollTo(id) // sin anchor: solo se mueve si la fila quedó fuera de vista
                }
            }
        }
        .overlay {
            if search.stations.isEmpty {
                if search.isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    emptyState
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Group {
                if search.trimmedQuery.isEmpty {
                    Text("Sin estaciones")
                } else {
                    Text("Sin resultados para “\(search.trimmedQuery)”")
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            Text("Prueba con un género como jazz o noticias.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .multilineTextAlignment(.center)
    }

    private var hints: some View {
        HStack(spacing: 14) {
            hint(["↑", "↓"], "Navegar")
            hint(["↩"], "Reproducir")
            hint(["esc"], "Cerrar")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func hint(_ keys: [String], _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 4)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            Text(label)
        }
    }
}
