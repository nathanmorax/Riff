//
//  RecentTile.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

// MARK: - Cuadro de estación reciente

struct RecentTile: View {

    let station: Station
    let isCurrent: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            StationTile(station: station, size: 44)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if isCurrent {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 4, height: 4)
                    .offset(y: 7)
                    .transition(.opacity)
            }
        }
        .offset(y: isHovering ? -2 : 0)
        .animation(.snappy(duration: 0.18), value: isHovering)
        .animation(.easeOut(duration: 0.2), value: isCurrent)
        .onHover { hovering in
            isHovering = hovering
            onHover(hovering)
        }
        .help(station.displayName)
        .accessibilityLabel("Reproducir \(station.displayName)")
    }
}
