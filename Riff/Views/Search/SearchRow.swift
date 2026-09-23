//
//  SearchRow.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

// MARK: - Fila de resultado

struct SearchRow: View {

    let station: Station
    let isSelected: Bool
    let isPlaying: Bool
    /// Namespace compartido por la lista, para que el resaltado se deslice entre filas.
    let highlight: Namespace.ID

    var body: some View {
        HStack(spacing: 11) {
            StationTile(station: station)

            VStack(alignment: .leading, spacing: 2) {
                Text(station.displayName)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if station.countryName != nil || !station.genres.isEmpty {
                    HStack(spacing: 5) {
                        // El país no se trunca; si falta espacio, se recortan los géneros.
                        if let country = station.countryName {
                            Text(country)
                                .foregroundStyle(Color.primary.opacity(0.75))
                                .layoutPriority(1)
                        }

                        if station.countryName != nil && !station.genres.isEmpty {
                            Text(verbatim: "·")
                                .foregroundStyle(.tertiary)
                        }

                        if !station.genres.isEmpty {
                            Text(station.genres.replacingOccurrences(of: " · ", with: ", "))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 12))
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            trailing
                .frame(width: 26)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .matchedGeometryEffect(id: "highlight", in: highlight)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var trailing: some View {
        if isPlaying {
            WaveIndicator()
                .foregroundStyle(.primary)
                .transition(.opacity)
        } else if isSelected {
            Image(systemName: "play.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}
