//
//  SearchRow.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

struct SearchRow: View {

    let station: Station
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: station.faviconURL) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Image(systemName: "radio")
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(station.displayName)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if !station.genres.isEmpty {
                    Text(station.genres)
                        .font(.caption)
                        .opacity(0.7)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "play.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
    }
}
