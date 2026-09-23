//
//  RadioBrowserAPI.swift
//  Riff
//
//  Created by Satori Tech 341 on 19/09/26.
//
import Foundation

// MARK: - Cliente HTTP de radio-browser.info

/// Solo arma las peticiones y decodifica. Las reglas (qué pedir, cómo combinar) viven en el repositorio.
struct RadioBrowserAPI {

    /// `all.api` reparte las peticiones entre los servidores espejo, como recomienda la documentación.
    var baseURL = "https://all.api.radio-browser.info"
    var session: URLSession = .shared

    /// `GET /json/stations/search` con los filtros dados, ordenado por popularidad y sin estaciones rotas.
    func searchStations(_ filters: [URLQueryItem], limit: Int) async throws -> [Station] {
        try await get("/json/stations/search", filters + [
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "hidebroken", value: "true")
        ])
    }

    /// `GET /json/stations/topclick`: las más escuchadas del mundo.
    func topClick(limit: Int) async throws -> [Station] {
        try await get("/json/stations/topclick", [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "hidebroken", value: "true")
        ])
    }

    // MARK: Petición

    private func get(_ path: String, _ items: [URLQueryItem]) async throws -> [Station] {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = items

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Riff/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)

        return try JSONDecoder().decode([Station].self, from: data)
    }
}
