//
//  RiffApp.swift
//  Riff
//
//  Created by Satori Tech 341 on 19/09/26.
//
import SwiftUI

// MARK: - Composition root

/// Aquí se arma todo: Data → Repositories → ViewModels → Views.
/// Es el único lugar que conoce las implementaciones concretas.
@main
struct RiffApp: App {

    @State private var player: PlayerViewModel
    @State private var search: SearchViewModel
    @State private var globe: MenuBarGlobe
    @State private var nowPlaying: NowPlayingController

    init() {
        // Data + Repositories
        let stationRepository = RadioBrowserStationRepository(api: RadioBrowserAPI())
        let libraryRepository = UserDefaultsLibraryRepository()

        // ViewModels
        let player = PlayerViewModel(
            audio: AudioStreamPlayer(),
            library: libraryRepository,
            stations: stationRepository
        )
        let search = SearchViewModel(player: player, repository: stationRepository)

        // Ícono de la barra: gira solo mientras suena; quieto en pausa o sin estación.
        let globe = MenuBarGlobe()
        globe.follow { player.isPlaying }

        _player = State(initialValue: player)
        _search = State(initialValue: search)
        _globe = State(initialValue: globe)

        // Teclas de medios (⏯) y "Reproduciendo ahora" del Centro de control.
        _nowPlaying = State(initialValue: NowPlayingController(player: player))
    }

    var body: some Scene {
        MenuBarExtra {
            PlayerView(player: player, search: search)
        } label: {
            Image(nsImage: globe.image)
                .renderingMode(.template)
                .accessibilityLabel(Text(verbatim: "Knob"))
        }
        .menuBarExtraStyle(.window)
    }
}
