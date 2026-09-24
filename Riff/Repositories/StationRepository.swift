//
//  StationRepository.swift
//  Riff
//
//  Created by Satori Tech 341 on 23/09/26.
//
import Foundation

// MARK: - Contrato

/// De dónde salen las estaciones de la búsqueda.
/// `SearchViewModel` depende de este protocolo, no de la API: se puede cambiar el backend o usar un mock.
protocol StationRepository {
    /// Estaciones que coinciden con `query` por nombre o por género. Con `query` vacío: las populares.
    func stations(matching query: String) async throws -> [Station]

    /// Avisa que el usuario empezó a escuchar `station`. Es de cortesía: si falla, no pasa nada.
    func registerPlay(of station: Station) async
}

// MARK: - radio-browser.info

struct RadioBrowserStationRepository: StationRepository {

    let api: RadioBrowserAPI
    /// País del usuario ("MX", "US"…). Solo decide qué va primero; nunca limita la búsqueda.
    var regionCode: String? = Self.currentRegionCode
    var limit = 20
    /// Si el país tiene menos populares que esto, se completa con las del mundo.
    var minimumLocalResults = 10

    /// Códecs que AVPlayer no reproduce en streams: aunque la estación funcione, aquí no cargaría.
    static let unsupportedCodecs: Set<String> = ["OGG", "OPUS", "FLAC", "WMA", "VORBIS"]

    /// Quita las estaciones con un códec que AVPlayer no soporta. Sin códec conocido, se deja pasar.
    static func playable(_ stations: [Station]) -> [Station] {
        stations.filter { station in
            guard let codec = station.codec?.uppercased() else { return true }
            return !unsupportedCodecs.contains(codec)
        }
    }

    /// Región del sistema (Ajustes → General → Idioma y región). No pide permiso de ubicación.
    static var currentRegionCode: String? {
        guard let code = Locale.current.region?.identifier, code.count == 2 else { return nil }
        return code.uppercased()
    }

    func stations(matching query: String) async throws -> [Station] {
        if query.isEmpty {
            return try await popular()
        }
        return try await search(query)
    }

    // MARK: Sin texto: populares

    /// Las más escuchadas del país del usuario; si son pocas, se completan con las del mundo.
    private func popular() async throws -> [Station] {
        let api = self.api
        let limit = self.limit

        var local: [Station] = []
        if let regionCode {
            // Si falla la del país, seguimos con las globales en vez de mostrar error.
            local = Self.playable((try? await api.searchStations([URLQueryItem(name: "countrycode", value: regionCode)], limit: limit)) ?? [])
        }

        guard local.count < minimumLocalResults else { return local }

        let global = try await api.topClick(limit: limit)
        return Self.popular(local: local, global: global, limit: limit)
    }

    /// Locales primero y después globales, sin duplicados.
    static func popular(local: [Station], global: [Station], limit: Int) -> [Station] {
        var seen = Set<String>()
        return Array(playable(local + global).filter { seen.insert($0.id).inserted }.prefix(limit))
    }

    // MARK: Con texto: búsqueda en todo el mundo

    /// Busca `query` como nombre y como género en todo el mundo (y como género en el país del usuario,
    /// para que "jazz" muestre también el jazz local). Los resultados del país van primero.
    private func search(_ query: String) async throws -> [Station] {
        let api = self.api
        let limit = self.limit
        let regionCode = self.regionCode

        // Las peticiones corren en paralelo.
        async let byName = api.searchStations([URLQueryItem(name: "name", value: query)], limit: limit)
        async let byGenre = api.searchStations([URLQueryItem(name: "tag", value: query)], limit: limit)
        async let localGenre = Self.localGenre(query, regionCode: regionCode, api: api, limit: limit)

        let (nameResults, genreResults, localResults) = try await (byName, byGenre, localGenre)

        return Self.ranked(nameResults + genreResults + localResults, regionCode: regionCode, limit: limit)
    }

    private static func localGenre(_ query: String, regionCode: String?, api: RadioBrowserAPI, limit: Int) async throws -> [Station] {
        guard let regionCode else { return [] }
        return try await api.searchStations([
            URLQueryItem(name: "tag", value: query),
            URLQueryItem(name: "countrycode", value: regionCode)
        ], limit: limit)
    }

    /// Quita duplicados; primero las del país del usuario, después por popularidad; recorta a `limit`.
    func registerPlay(of station: Station) async {
        try? await api.registerClick(stationID: station.stationUUID)
    }

    static func ranked(_ stations: [Station], regionCode: String?, limit: Int) -> [Station] {
        var seen = Set<String>()
        let unique = playable(stations).filter { seen.insert($0.id).inserted }

        func isLocal(_ station: Station) -> Bool {
            guard let regionCode, let code = station.countryCode else { return false }
            return code.uppercased() == regionCode
        }

        let sorted = unique.sorted { a, b in
            let (aLocal, bLocal) = (isLocal(a), isLocal(b))
            if aLocal != bLocal { return aLocal }
            return (a.clickcount ?? 0) > (b.clickcount ?? 0)
        }
        return Array(sorted.prefix(limit))
    }
}
