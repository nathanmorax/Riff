//
//  RiffTests.swift
//  RiffTests
//
//  Created by Satori Tech 341 on 16/09/26.
//

import XCTest
@testable import Riff

// MARK: - Dobles de prueba

/// Reproductor falso: no toca AVFoundation, solo registra lo que le piden.
@MainActor
private final class MockAudio: AudioStreaming {
    let statusUpdates: AsyncStream<PlaybackStatus>
    let titleUpdates: AsyncStream<String>
    let status: AsyncStream<PlaybackStatus>.Continuation
    let titles: AsyncStream<String>.Continuation

    private(set) var playedURLs: [URL] = []
    private(set) var stopCount = 0

    init() {
        let (s, sc) = AsyncStream.makeStream(of: PlaybackStatus.self)
        let (t, tc) = AsyncStream.makeStream(of: String.self)
        statusUpdates = s; status = sc
        titleUpdates = t; titles = tc
    }

    func play(url: URL) { playedURLs.append(url) }
    func stop() { stopCount += 1 }
}

@MainActor
private func makeStation(_ id: String, clicks: Int = 0, country: String? = nil, codec: String? = nil) -> Station {
    Station(stationUUID: id, name: "Radio \(id)", urlResolved: "https://example.com/\(id)",
            favicon: nil, tags: "rock,pop", bitrate: 128, clickcount: clicks, countryCode: country, codec: codec)
}

/// Espera (máx. 1 s) a que `condition` se cumpla. El ViewModel consume el stream en su propio
/// Task, así que no hay un número fijo de `Task.yield()` que garantice que ya procesó el valor.
@MainActor
private func waitUntil(timeout: Duration = .seconds(1), _ condition: () -> Bool) async {
    let deadline = ContinuousClock.now + timeout
    while !condition(), ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
}

// MARK: - LibraryRepository

final class LibraryRepositoryTests: XCTestCase {

    @MainActor
    func testRecordPlaybackMovesStationToFrontWithoutDuplicatesAndRespectsLimit() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let repo = UserDefaultsLibraryRepository(defaults: defaults, recentsLimit: 3)

        ["a", "b", "c", "d", "b"].forEach { repo.recordPlayback(of: makeStation($0)) }

        XCTAssertEqual(repo.recentStations.map(\.id), ["b", "d", "c"])
        XCTAssertEqual(repo.lastStation?.id, "b")
    }
}

// MARK: - PlayerViewModel

final class PlayerViewModelTests: XCTestCase {

    /// Primera vez que se abre la app: no hay nada guardado, así que `PlayerView`
    /// muestra la bienvenida ("Sintoniza algo nuevo.") en lugar del reproductor.
    @MainActor
    func testFirstLaunchHasNoStationSoWelcomeIsShown() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let vm = PlayerViewModel(audio: MockAudio(), library: UserDefaultsLibraryRepository(defaults: defaults))

        XCTAssertNil(vm.currentStation)
        XCTAssertTrue(vm.recents.isEmpty)
        XCTAssertFalse(vm.isActive)
    }

    /// Después de escuchar una estación, el siguiente lanzamiento ya no muestra la bienvenida:
    /// abre el reproductor con esa estación, detenida (no suena sola).
    @MainActor
    func testNextLaunchRestoresLastStationSoPlayerIsShown() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let firstLaunch = PlayerViewModel(audio: MockAudio(), library: UserDefaultsLibraryRepository(defaults: defaults))
        firstLaunch.play(makeStation("x"))

        let audio = MockAudio()
        let nextLaunch = PlayerViewModel(audio: audio, library: UserDefaultsLibraryRepository(defaults: defaults))

        XCTAssertEqual(nextLaunch.currentStation?.id, "x")
        XCTAssertEqual(nextLaunch.recents.map(\.id), ["x"])
        XCTAssertTrue(audio.playedURLs.isEmpty, "Al abrir la app no debe empezar a sonar sola")
    }

    @MainActor
    func testPlayUpdatesCurrentStationRecentsAndStartsAudio() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let audio = MockAudio()
        let vm = PlayerViewModel(audio: audio, library: UserDefaultsLibraryRepository(defaults: defaults))

        vm.play(makeStation("x"))

        XCTAssertEqual(vm.currentStation?.id, "x")
        XCTAssertEqual(vm.recents.map(\.id), ["x"])
        XCTAssertEqual(audio.playedURLs, [URL(string: "https://example.com/x")!])
    }

    @MainActor
    func testStatusFromAudioIsReflected() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let audio = MockAudio()
        let vm = PlayerViewModel(audio: audio, library: UserDefaultsLibraryRepository(defaults: defaults))

        audio.status.yield(.failed)
        await waitUntil { vm.hasFailed }

        XCTAssertTrue(vm.hasFailed)
        XCTAssertFalse(vm.isActive)
    }
}

// MARK: - StationRepository (reglas de orden)

final class StationRepositoryTests: XCTestCase {

    @MainActor
    func testSearchPutsUserCountryFirstThenByPopularity() {
        let results = [
            makeStation("bbc", clicks: 900, country: "GB"),
            makeStation("mx-small", clicks: 10, country: "MX"),
            makeStation("nts", clicks: 500, country: "GB"),
            makeStation("mx-big", clicks: 300, country: "mx"),
            makeStation("bbc", clicks: 900, country: "GB") // duplicado (llegó por nombre y por género)
        ]

        let ranked = RadioBrowserStationRepository.ranked(results, regionCode: "MX", limit: 10)

        XCTAssertEqual(ranked.map(\.id), ["mx-big", "mx-small", "bbc", "nts"])
    }

    @MainActor
    func testSearchWithoutRegionIsOnlyByPopularity() {
        let results = [makeStation("a", clicks: 1, country: "MX"), makeStation("b", clicks: 5, country: "US")]

        let ranked = RadioBrowserStationRepository.ranked(results, regionCode: nil, limit: 10)

        XCTAssertEqual(ranked.map(\.id), ["b", "a"])
    }

    @MainActor
    func testUnsupportedCodecsAreDiscarded() {
        let results = [
            makeStation("mp3", codec: "MP3"),
            makeStation("ogg", codec: "OGG"),
            makeStation("opus", codec: "opus"),
            makeStation("unknown")
        ]

        let ranked = RadioBrowserStationRepository.ranked(results, regionCode: nil, limit: 10)

        XCTAssertEqual(Set(ranked.map(\.id)), ["mp3", "unknown"])
    }

    @MainActor
    func testPopularFillsWithGlobalWithoutDuplicates() {
        let local = [makeStation("l1"), makeStation("l2")]
        let global = [makeStation("g1"), makeStation("l1"), makeStation("g2")]

        let popular = RadioBrowserStationRepository.popular(local: local, global: global, limit: 4)

        XCTAssertEqual(popular.map(\.id), ["l1", "l2", "g1", "g2"])
    }
}
