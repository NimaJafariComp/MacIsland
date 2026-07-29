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
