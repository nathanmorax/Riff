//
//  SearchViewModel.swift
//  Riff
//
//  Created by Satori Tech 341 on 23/09/26.
//
import SwiftUI
import Observation

// MARK: - Estado de la búsqueda

/// ViewModel de la búsqueda. Compartido entre el campo (en el popover) y los resultados
/// (en el panel flotante), porque viven en ventanas distintas.
/// Pide las estaciones a `StationRepository` y le pasa la elegida a `PlayerViewModel`.
@MainActor
@Observable
final class SearchViewModel {

    var query = "" {
        didSet {
            guard trimmed(query) != trimmed(oldValue) else { return }
            if !trimmed(query).isEmpty { present() }
            scheduleSearch()
        }
    }

    private(set) var stations: [Station] = []
    private(set) var isSearching = false
    private(set) var isPresented = false
    var selection: Station.ID?

    @ObservationIgnored private let player: PlayerViewModel
    @ObservationIgnored private let repository: any StationRepository
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    private let selectionAnimation = Animation.snappy(duration: 0.18)

    init(player: PlayerViewModel, repository: any StationRepository) {
        self.player = player
        self.repository = repository
    }

    var trimmedQuery: String { trimmed(query) }

    // MARK: Mostrar / ocultar

    func present() {
        guard !isPresented else { return }
        isPresented = true
        if stations.isEmpty { scheduleSearch() }
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
    }

    // MARK: Selección

    func moveSelection(by delta: Int) {
        guard isPresented, !stations.isEmpty else { return }

        let current = stations.firstIndex { $0.id == selection } ?? -1
        let next = min(max(current + delta, 0), stations.count - 1)
        withAnimation(selectionAnimation) {
            selection = stations[next].id
        }
    }

    func select(_ id: Station.ID) {
        guard selection != id else { return }
        withAnimation(selectionAnimation) {
            selection = id
        }
    }

    // MARK: Reproducir (el panel se queda abierto para seguir probando)

    func playSelected() {
        guard isPresented else { return }
        guard let station = stations.first(where: { $0.id == selection }) ?? stations.first else { return }
        play(station)
    }

    func play(_ station: Station) {
        selection = station.id
        player.play(station)
    }

    // MARK: Búsqueda

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = trimmedQuery
        searchTask = Task { [weak self] in
            await self?.search(query)
        }
    }

    private func search(_ query: String) async {
        isSearching = true

        // Debounce: si el usuario sigue escribiendo, el task se cancela y el sleep se interrumpe.
        if !query.isEmpty {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
        }

        do {
            let result = try await repository.stations(matching: query)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                stations = result
                selection = result.first?.id
            }
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            #if DEBUG
            print("[Knob] ❌ Error de búsqueda: \(error)")
            #endif
            stations = []
            selection = nil
        }

        isSearching = false
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
