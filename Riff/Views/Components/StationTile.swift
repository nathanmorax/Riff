//
//  StationTile.swift
//  Riff
//
//  Created by Nathan Mora on 21/09/26.
//
import SwiftUI
import AppKit

// MARK: - Logo de la estación

/// Cuadro de 36 pt: el favicon si carga, o un monograma con color estable si no.
struct StationTile: View {

    let station: Station
    var size: CGFloat = 36

    #if DEBUG
    /// Logos ya descargados para `ScreenshotExporter`: ImageRenderer no espera a AsyncImage.
    static var snapshotImages: [URL: NSImage] = [:]
    #endif

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if let url = station.faviconURL, let image = Self.snapshotImages[url] {
            logo(Image(nsImage: image))
        } else {
            remoteLogo
        }
        #else
        remoteLogo
        #endif
    }

    private var remoteLogo: some View {
        AsyncImage(url: station.faviconURL) { phase in
            if let image = phase.image {
                logo(image)
            } else {
                monogram
            }
        }
    }

    private func logo(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .background(Color.primary.opacity(0.06))
    }

    private var monogram: some View {
        ZStack {
            tint
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var initials: String {
        let words = station.displayName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return words.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    /// Color apagado y estable por nombre (hashValue cambia entre lanzamientos, por eso no se usa).
    private var tint: Color {
        let palette: [Color] = [
            Color(red: 0.23, green: 0.23, blue: 0.24),
            Color(red: 0.17, green: 0.24, blue: 0.31),
            Color(red: 0.29, green: 0.18, blue: 0.18),
            Color(red: 0.18, green: 0.25, blue: 0.21),
            Color(red: 0.24, green: 0.20, blue: 0.31),
            Color(red: 0.29, green: 0.25, blue: 0.19),
            Color(red: 0.15, green: 0.25, blue: 0.29)
        ]
        let sum = station.displayName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}
