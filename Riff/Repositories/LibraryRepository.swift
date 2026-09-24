//
//  LibraryRepository.swift
//  Riff
//
//  Created by Nathan Mora on 23/09/26.
//
import Foundation

// MARK: - Contrato

/// Lo que el usuario ya escuchó: la última estación y las recientes.
protocol LibraryRepository {
    /// La última estación reproducida; `nil` solo la primera vez que se abre la app.
    var lastStation: Station? { get }
    /// Las recientes, la más nueva primero.
    var recentStations: [Station] { get }
    /// Guarda `station` como la última y la pone al frente de las recientes, sin duplicados.
    func recordPlayback(of station: Station)
}

// MARK: - UserDefaults

/// Usa las mismas claves que la versión anterior, así no se pierde lo que ya estaba guardado.
final class UserDefaultsLibraryRepository: LibraryRepository {

    private enum Key {
        static let lastStation = "lastStation"
        static let recentStations = "riff.recentStations"
    }

    private let defaults: UserDefaults
    private let recentsLimit: Int

    init(defaults: UserDefaults = .standard, recentsLimit: Int = 5) {
        self.defaults = defaults
        self.recentsLimit = recentsLimit
    }

    var lastStation: Station? {
        load(Station.self, forKey: Key.lastStation)
    }

    var recentStations: [Station] {
        load([Station].self, forKey: Key.recentStations) ?? []
    }

    func recordPlayback(of station: Station) {
        save(station, forKey: Key.lastStation)

        var recents = recentStations.filter { $0.id != station.id }
        recents.insert(station, at: 0)
        save(Array(recents.prefix(recentsLimit)), forKey: Key.recentStations)
    }

    // MARK: Codable ↔ Data

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
