//
//  Station.swift
//  Riff
//
//  Created by Nathan Mora on 19/09/26.
//
import Foundation

// MARK: - Model

struct Station: Codable, Identifiable {
    let stationUUID: String
    let name: String
    let urlResolved: String
    let favicon: String?
    let tags: String
    let bitrate: Int
    let clickcount: Int?
    /// Código ISO de 2 letras del país de la estación ("MX", "US"…).
    let countryCode: String?
    /// Códec del stream según radio-browser ("MP3", "AAC", "OGG"…).
    let codec: String?

    var id: String {
        stationUUID
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        var clean = trimmed
        for separator in [" - ", " – ", " — ", " | "] {
            if let range = clean.range(of: separator) {
                clean = String(clean[..<range.lowerBound])
            }
        }

        // "UNIVERSAL 88.1 (CDMX)" -> "UNIVERSAL 88.1"
        clean = clean.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        // Si la limpieza se comió casi todo, mejor el nombre original.
        return clean.count >= 2 ? clean : trimmed
    }

    /// Primeros géneros de la estación: "pop · rock · mexicana".
    var genres: String {
        tags
            .split(separator: ",")
            .prefix(3)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Muchos favicons vienen por http://, que App Transport Security bloquea.
    /// Probamos con https://; si el servidor no lo soporta, se queda el placeholder.
    var faviconURL: URL? {
        guard var favicon = favicon?.trimmingCharacters(in: .whitespacesAndNewlines),
              !favicon.isEmpty else { return nil }

        favicon = favicon.replacingOccurrences(of: "http://", with: "https://", options: .anchored)
        return URL(string: favicon)
    }

    /// Nombre del país en el idioma del usuario: "MX" → "México".
    var countryName: String? {
        guard let code = countryCode?.trimmingCharacters(in: .whitespaces), code.count == 2 else { return nil }
        return Locale.current.localizedString(forRegionCode: code.uppercased())
    }

    enum CodingKeys: String, CodingKey {
        case stationUUID = "stationuuid"
        case name
        case urlResolved = "url_resolved"
        case favicon
        case tags
        case bitrate
        case clickcount
        case countryCode = "countrycode"
        case codec
    }
}
