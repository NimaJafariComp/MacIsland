import AVFoundation
import AppKit
import Combine
import Defaults
import XCTest
@testable import MacIsland

@MainActor
final class MacIslandTests: XCTestCase {
    func testOpenAndCloseStateMachine() {
        let viewModel = BoringViewModel()

        viewModel.open()
        XCTAssertEqual(viewModel.notchState, .open)

        viewModel.close()
        XCTAssertEqual(viewModel.notchState, .closed)
        viewModel.destroy()
    }

    func testGeometryStaysWithinTheActiveDisplay() {
        guard let screen = NSScreen.main else {
            return XCTFail("A macOS test host must have a main screen")
        }

        let metrics = NotchMetrics(screen: screen)
        XCTAssertGreaterThan(metrics.closedIslandSize.width, 0)
        XCTAssertGreaterThanOrEqual(metrics.closedIslandSize.height, 0)
        XCTAssertLessThanOrEqual(metrics.openIslandSize.width, screen.frame.width)
        XCTAssertLessThanOrEqual(metrics.openIslandSize.height, screen.visibleFrame.height)
    }

    func testDragStateCombinesAllDropTargets() {
        let viewModel = BoringViewModel()

        viewModel.dragDetectorTargeting = true
        XCTAssertTrue(viewModel.anyDropZoneTargeting)
        viewModel.dragDetectorTargeting = false
        viewModel.generalDropTargeting = true
        XCTAssertTrue(viewModel.anyDropZoneTargeting)
        viewModel.generalDropTargeting = false
        viewModel.dropZoneTargeting = true
        XCTAssertTrue(viewModel.anyDropZoneTargeting)
        viewModel.destroy()
    }

    func testSettingsMigrationClampsOutOfRangeValues() {
        let originalNotchHeight = Defaults[.notchHeight]
        let originalNonNotchHeight = Defaults[.nonNotchHeight]
        defer {
            Defaults[.notchHeight] = originalNotchHeight
            Defaults[.nonNotchHeight] = originalNonNotchHeight
        }

        Defaults[.notchHeight] = 500
        Defaults[.nonNotchHeight] = -1
        SettingsMigration.apply()

        XCTAssertEqual(Defaults[.notchHeight], 45)
        XCTAssertEqual(Defaults[.nonNotchHeight], 16)
    }

    func testMediaAndCameraProtocolFailureSeams() async {
        let media = FailingMediaController()
        let camera = UnavailableCamera()

        XCTAssertFalse(media.isActive())
        await media.play()
        XCTAssertEqual(media.playAttempts, 1)
        XCTAssertEqual(camera.authorizationStatus, .denied)
        XCTAssertFalse(camera.cameraAvailable)
        camera.startSession()
        XCTAssertFalse(camera.isSessionRunning)
    }

    func testCountdownTimerSupportsPauseResumeAndStop() {
        let coordinator = BoringViewCoordinator.shared
        defer { coordinator.stopTimer() }

        coordinator.startTimer(seconds: 0)
        XCTAssertEqual(coordinator.timerStatus, .running)
        XCTAssertGreaterThan(coordinator.timerRemaining, 0)

        coordinator.toggleTimerPause()
        XCTAssertEqual(coordinator.timerStatus, .paused)

        coordinator.toggleTimerPause()
        XCTAssertEqual(coordinator.timerStatus, .running)

        coordinator.stopTimer()
        XCTAssertEqual(coordinator.timerStatus, .idle)
        XCTAssertEqual(coordinator.timerRemaining, 0)
    }

    func testPersistedCountdownRecoveryHonorsElapsedAndPausedTime() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let running = PersistedCountdownTimer.running(until: now.addingTimeInterval(90))
        XCTAssertEqual(running.remaining(at: now.addingTimeInterval(30)), 60)
        XCTAssertEqual(running.remaining(at: now.addingTimeInterval(100)), 0)

        let paused = PersistedCountdownTimer.paused(remaining: 45)
        XCTAssertEqual(paused.remaining(at: now.addingTimeInterval(10_000)), 45)
    }

    func testTimerNotificationUsesStableIdentifierAndNativeContent() {
        let content = TimerCompletionNotification.content()
        XCTAssertEqual(TimerCompletionNotification.identifier, "macisland.countdown-complete")
        XCTAssertEqual(content.title, "Timer finished")
        XCTAssertEqual(content.sound, .default)
    }

    func testTimerPresetNormalizesNameAndDuration() {
        let preset = TimerPreset(name: "  Focus session  ", seconds: 5)
        XCTAssertEqual(preset.name, "Focus session")
        XCTAssertEqual(preset.seconds, 60)
        XCTAssertEqual(preset.durationLabel, "1m")
    }

    func testStopwatchSupportsPauseResumeAndStop() {
        let coordinator = BoringViewCoordinator.shared
        defer { coordinator.stopTimer() }

        coordinator.startStopwatch()
        XCTAssertEqual(coordinator.timerMode, .stopwatch)
        XCTAssertEqual(coordinator.timerStatus, .running)

        coordinator.toggleTimerPause()
        XCTAssertEqual(coordinator.timerStatus, .paused)

        coordinator.toggleTimerPause()
        XCTAssertEqual(coordinator.timerStatus, .running)

        coordinator.stopTimer()
        XCTAssertEqual(coordinator.timerStatus, .idle)
        XCTAssertEqual(coordinator.stopwatchElapsed, 0)
    }

    func testWeatherTemperatureFormattingUsesSelectedUnit() {
        let snapshot = WeatherSnapshot(
            location: "Austin",
            temperatureCelsius: 20,
            weatherCode: 0,
            updatedAt: .now
        )

        XCTAssertEqual(snapshot.formattedTemperature(in: .celsius), "20°C")
        XCTAssertEqual(snapshot.formattedTemperature(in: .fahrenheit), "68°F")
    }

    func testWeatherNetworkSeamsDecodeOpenMeteoResponses() async throws {
        let loader: WeatherDataLoader = { url in
            let json: String
            if url.host == "geocoding-api.open-meteo.com" {
                json = #"{"results":[{"latitude":30.2672,"longitude":-97.7431}]}"#
            } else {
                json = #"{"current":{"temperature_2m":20.4,"weather_code":2}}"#
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(json.utf8), response)
        }

        let coordinate = try await BoringViewCoordinator.resolveWeatherLocation(named: "Austin", dataLoader: loader)
        XCTAssertEqual(coordinate.latitude, 30.2672)
        XCTAssertEqual(coordinate.longitude, -97.7431)

        let snapshot = try await BoringViewCoordinator.fetchWeather(
            for: coordinate,
            displayName: "Austin",
            dataLoader: loader
        )
        XCTAssertEqual(snapshot.location, "Austin")
        XCTAssertEqual(snapshot.temperatureCelsius, 20.4)
        XCTAssertEqual(snapshot.weatherCode, 2)
    }

    func testWeatherNetworkSeamsRejectBadStatus() async {
        let loader: WeatherDataLoader = { url in
            let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        do {
            _ = try await BoringViewCoordinator.resolveWeatherLocation(named: "Austin", dataLoader: loader)
            XCTFail("Expected bad HTTP status to fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    func testHigherPriorityActivityPreemptsMedia() {
        let coordinator = BoringViewCoordinator.shared
        defer {
            coordinator.toggleSneakPeek(status: false, type: .music)
            coordinator.toggleExpandingView(status: false, type: .battery)
        }

        coordinator.toggleSneakPeek(status: true, type: .music)
        XCTAssertTrue(coordinator.sneakPeek.show)

        coordinator.toggleExpandingView(status: true, type: .battery)
        XCTAssertEqual(coordinator.expandingView.type, .battery)
    }

    func testClipboardHistoryIsOptInAndDeduplicated() {
        let originalEnabled = Defaults[.clipboardHistoryEnabled]
        let originalLimit = Defaults[.clipboardHistoryLimit]
        let coordinator = BoringViewCoordinator.shared
        defer {
            coordinator.clearClipboardHistory()
            Defaults[.clipboardHistoryEnabled] = originalEnabled
            Defaults[.clipboardHistoryLimit] = originalLimit
        }

        Defaults[.clipboardHistoryEnabled] = true
        Defaults[.clipboardHistoryLimit] = 2
        coordinator.clearClipboardHistory()
        coordinator.recordClipboardText("first")
        coordinator.recordClipboardText("second")
        coordinator.recordClipboardText("first")

        XCTAssertEqual(coordinator.clipboardEntries.map(\.text), ["first", "second"])
    }

    func testClipboardPrivacyFiltersAppsAndRichContent() {
        XCTAssertFalse(BoringViewCoordinator.shouldCaptureClipboard(
            frontmostBundleIdentifier: "com.apple.Notes",
            excludedBundleIdentifiers: "com.apple.Notes, com.1password.1password"
        ))
        XCTAssertTrue(BoringViewCoordinator.shouldCaptureClipboard(
            frontmostBundleIdentifier: "com.apple.TextEdit",
            excludedBundleIdentifiers: "com.apple.Notes"
        ))
        XCTAssertFalse(BoringViewCoordinator.shouldCaptureClipboard(
            types: [.string, .rtf],
            allowsRichText: false
        ))
        XCTAssertTrue(BoringViewCoordinator.shouldCaptureClipboard(
            types: [.string, .rtf],
            allowsRichText: true
        ))
        XCTAssertFalse(BoringViewCoordinator.shouldCaptureClipboard(
            types: [.rtf],
            allowsRichText: true
        ))
    }

    func testShelfSelectionKeyboardNavigationClampsAtEnds() {
        let first = ShelfItem(kind: .text(string: "one"))
        let second = ShelfItem(kind: .text(string: "two"))
        let selection = ShelfSelectionModel.shared
        defer { selection.clear() }

        selection.moveSelection(by: 1, in: [first, second])
        XCTAssertTrue(selection.isSelected(first.id))
        selection.moveSelection(by: 1, in: [first, second])
        XCTAssertTrue(selection.isSelected(second.id))
        selection.moveSelection(by: 1, in: [first, second])
        XCTAssertTrue(selection.isSelected(second.id))
        selection.moveSelection(by: -1, in: [first, second])
        XCTAssertTrue(selection.isSelected(first.id))
    }
}

private final class FailingMediaController: MediaControllerProtocol {
    let playbackStatePublisher = Just(PlaybackState(bundleIdentifier: "test")).eraseToAnyPublisher()
    var supportsVolumeControl: Bool { false }
    var supportsFavorite: Bool { false }
    private(set) var playAttempts = 0

    func setFavorite(_ favorite: Bool) async {}
    func play() async { playAttempts += 1 }
    func pause() async {}
    func seek(to time: Double) async {}
    func nextTrack() async {}
    func previousTrack() async {}
    func togglePlay() async {}
    func toggleShuffle() async {}
    func toggleRepeat() async {}
    func setVolume(_ level: Double) async {}
    func isActive() -> Bool { false }
    func updatePlaybackInfo() async {}
    func shutdown() {}
}

private final class UnavailableCamera: CameraSessionControlling {
    let authorizationStatus: AVAuthorizationStatus = .denied
    let cameraAvailable = false
    private(set) var isSessionRunning = false

    func requestAccessAndStart() {}
    func startSession() { isSessionRunning = false }
    func stopSession() { isSessionRunning = false }
}
