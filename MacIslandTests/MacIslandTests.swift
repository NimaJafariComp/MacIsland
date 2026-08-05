import AVFoundation
import AppKit
import Combine
import Defaults
import EventKit
import XCTest
@testable import MacIsland

@MainActor
final class MacIslandTests: XCTestCase {
    func testUIAuditStatesAcceptLaunchAliasesAndUniqueShortcuts() {
        XCTAssertEqual(UIAuditState(argument: "expanded"), .home)
        XCTAssertEqual(UIAuditState(argument: "dismissed"), .closed)
        XCTAssertEqual(UIAuditState(argument: "MEDIA"), .media)
        XCTAssertEqual(UIAuditState(argument: "media-playing"), .mediaPlaying)
        XCTAssertEqual(UIAuditState(argument: "media-paused"), .mediaPaused)
        XCTAssertEqual(UIAuditState(argument: "calendar"), .calendarStress)
        XCTAssertEqual(UIAuditState(argument: "calendar-stress"), .calendarStress)
        XCTAssertEqual(UIAuditState(argument: "calendar-home"), .calendarHomeStress)
        XCTAssertEqual(UIAuditState(argument: "calendar-home-stress"), .calendarHomeStress)
        XCTAssertEqual(UIAuditState(argument: "snippets-stress"), .snippetsStress)
        XCTAssertEqual(UIAuditState(argument: "unknown"), .closed)

        XCTAssertEqual(UIAuditState(shortcut: "1"), .closed)
        XCTAssertEqual(UIAuditState(shortcut: "2"), .hover)
        XCTAssertEqual(UIAuditState(shortcut: "3"), .home)
        XCTAssertEqual(UIAuditState(shortcut: "4"), .shelf)
        XCTAssertEqual(UIAuditState(shortcut: "5"), .timer)
        XCTAssertEqual(UIAuditState(shortcut: "6"), .media)
        XCTAssertEqual(UIAuditState(shortcut: "7"), .camera)
        XCTAssertEqual(UIAuditState(shortcut: "8"), .error)
        XCTAssertEqual(UIAuditState(shortcut: "9"), .accessibility)
        XCTAssertNil(UIAuditState(shortcut: "0"))
    }

    func testExpandedPageSizingUsesCompactFloorAndContentCaps() {
        XCTAssertEqual(IslandExpandedPageSizing.snippetsHeight(entryCount: 0), 190)
        XCTAssertEqual(IslandExpandedPageSizing.snippetsHeight(entryCount: 8), 358)
        XCTAssertEqual(IslandExpandedPageSizing.snippetsHeight(entryCount: 100), 440)

        XCTAssertEqual(IslandExpandedPageSizing.calendarHeight(itemCount: 0), 220)
        XCTAssertEqual(IslandExpandedPageSizing.calendarHeight(itemCount: 4), 234)
        XCTAssertEqual(IslandExpandedPageSizing.calendarHeight(itemCount: 9), 394)
        XCTAssertEqual(IslandExpandedPageSizing.calendarHeight(itemCount: 100), 900)
    }

    func testCalendarHomeStatusMessageDistinguishesAccessStates() {
        XCTAssertEqual(
            CalendarAccessPolicy.homeStatusMessage(for: .notDetermined),
            "Allow Calendar Access in Settings"
        )
        XCTAssertEqual(
            CalendarAccessPolicy.homeStatusMessage(for: .denied),
            "Calendar access denied in System Settings"
        )
        XCTAssertEqual(
            CalendarAccessPolicy.homeStatusMessage(for: .restricted),
            "Calendar access denied in System Settings"
        )
        XCTAssertNil(CalendarAccessPolicy.homeStatusMessage(for: .fullAccess))
    }

    func testReminderAccessibilityNamesTheReminderAndItsCompletionAction() {
        XCTAssertEqual(
            CalendarReminderPresentation.rowLabel(title: "Pick up package"),
            "Reminder: Pick up package"
        )
        XCTAssertEqual(
            CalendarReminderPresentation.toggleLabel(title: "Pick up package", completed: false),
            "Mark Pick up package as complete"
        )
        XCTAssertEqual(
            CalendarReminderPresentation.toggleLabel(title: "Pick up package", completed: true),
            "Mark Pick up package as incomplete"
        )
    }

    func testHomeCalendarSummaryIncludesEventsAndReminders() {
        XCTAssertEqual(
            HomeCalendarSummaryPresentation.countLabel(itemCount: 1, reminderCount: 0),
            "1 item"
        )
        XCTAssertEqual(
            HomeCalendarSummaryPresentation.countLabel(itemCount: 9, reminderCount: 3),
            "9 items · 3 reminders"
        )
    }

    func testOpenAndCloseStateMachine() {
        let viewModel = BoringViewModel()

        viewModel.open()
        XCTAssertEqual(viewModel.notchState, .open)

        viewModel.close()
        XCTAssertEqual(viewModel.notchState, .closed)
        viewModel.destroy()
    }

    func testClosedActivitiesAreVisibleBeforeFullscreenDetectionPublishes() {
        let viewModel = BoringViewModel()
        defer { viewModel.destroy() }

        XCTAssertFalse(viewModel.hideOnClosed)
    }

    func testSystemStatePresentationUsesPrivateLabelsAndPublicReachabilityCopy() {
        let originalName = Defaults[.focusIndicatorName]
        defer { Defaults[.focusIndicatorName] = originalName }

        Defaults[.focusIndicatorName] = "  Deep work  "
        XCTAssertEqual(SystemStatePresentation.title(for: .focus, value: 1), "Deep work")
        XCTAssertEqual(SystemStatePresentation.detail(for: .focus, value: 0), "Focus ended")
        XCTAssertEqual(SystemStatePresentation.title(for: .connectivity, value: 1), "Connected")
        XCTAssertEqual(SystemStatePresentation.detail(for: .connectivity, value: 0), "No internet connection")
        XCTAssertFalse(SneakContentType.focus.requiresHUDReplacement)
        XCTAssertFalse(SneakContentType.connectivity.requiresHUDReplacement)
        XCTAssertTrue(SneakContentType.volume.requiresHUDReplacement)
    }

    func testLockScreenCollapsesTheIslandAndPreventsReopen() {
        let viewModel = BoringViewModel()
        defer { viewModel.destroy() }

        viewModel.open()
        viewModel.setScreenLocked(true)
        XCTAssertTrue(viewModel.isScreenLocked)
        XCTAssertEqual(viewModel.notchState, .closed)

        viewModel.open()
        XCTAssertEqual(viewModel.notchState, .closed)

        let scene = IslandSceneResolver.resolve(IslandSceneInput(
            isOnboarding: true,
            isOpen: true,
            currentView: .shelf,
            isBatteryActivityVisible: true,
            isSystemHUDVisible: true,
            isTimerVisible: true,
            isTimerCompleted: true,
            isMediaVisible: true,
            isIdleFaceVisible: true,
            isScreenLocked: true
        ))
        XCTAssertEqual(scene, .collapsed)
    }

    func testSettingsNavigationUsesTheFiveAuditedGroups() {
        XCTAssertEqual(
            SettingsNavigationGroup.allCases.map(\.rawValue),
            ["Appearance", "Behavior", "Gestures", "Modules", "Advanced"]
        )
        XCTAssertEqual(SettingsNavigationGroup.appearance.destinations, [.appearance])
        XCTAssertEqual(SettingsNavigationGroup.behavior.destinations, [.behavior])
        XCTAssertEqual(SettingsNavigationGroup.gestures.destinations, [.gestures])
        XCTAssertEqual(
            SettingsNavigationGroup.modules.destinations,
            [.media, .calendar, .timer, .weather, .hud, .battery, .systemStates, .shelf]
        )
        XCTAssertEqual(SettingsNavigationGroup.advanced.destinations, [.advanced, .about])
        XCTAssertEqual(SettingsDestination.gestures.title, "Controls & shortcuts")
        XCTAssertTrue(GestureSettingsPolicy.trackpadControlsAvailable(hoverOpenEnabled: false))
        XCTAssertFalse(GestureSettingsPolicy.trackpadControlsAvailable(hoverOpenEnabled: true))
    }

    func testReduceMotionPolicyStopsNonessentialVisualWork() {
        XCTAssertTrue(IslandMotion.allowsNonessentialMotion(reduceMotion: false))
        XCTAssertFalse(IslandMotion.allowsNonessentialMotion(reduceMotion: true))

        for phase in IslandMotionPhase.allCases {
            XCTAssertLessThanOrEqual(
                IslandMotion.durationBudget(for: phase, reduceMotion: false),
                0.65,
                "\\(phase) exceeds the island transition budget"
            )
            XCTAssertEqual(IslandMotion.durationBudget(for: phase, reduceMotion: true), 0.01)
        }

        XCTAssertEqual(IslandMotion.appKitStateDuration(reduceMotion: false), 0.28)
        XCTAssertEqual(IslandMotion.appKitStateDuration(reduceMotion: true), 0.01)
        XCTAssertTrue(IslandMotion.shouldAnimateAppKitStateChanges(reduceMotion: false))
        XCTAssertFalse(IslandMotion.shouldAnimateAppKitStateChanges(reduceMotion: true))

        let spectrum = AudioSpectrum(frame: .zero)
        defer { spectrum.setPlaying(false) }

        spectrum.setPlaying(true, reduceMotion: true)
        XCTAssertFalse(spectrum.isAnimating)

        spectrum.setPlaying(true, reduceMotion: false)
        XCTAssertTrue(spectrum.isAnimating)
    }

    func testIdleFaceMotionStopsWhenHiddenOrReduceMotionIsEnabled() {
        XCTAssertTrue(IdleFaceMotionPolicy.shouldAnimate(isVisible: true, reduceMotion: false))
        XCTAssertFalse(IdleFaceMotionPolicy.shouldAnimate(isVisible: false, reduceMotion: false))
        XCTAssertFalse(IdleFaceMotionPolicy.shouldAnimate(isVisible: true, reduceMotion: true))
    }

    func testIslandPaletteElevatesContrastForThemeAndSystemPreference() {
        XCTAssertFalse(IslandPalette(theme: .midnight, increaseContrast: false).usesHighContrast)
        XCTAssertTrue(IslandPalette(theme: .contrast, increaseContrast: false).usesHighContrast)
        XCTAssertTrue(IslandPalette(theme: .graphite, increaseContrast: true).usesHighContrast)
        XCTAssertEqual(IslandPalette(theme: .frost, increaseContrast: true).borderOpacity, 0.32)
        XCTAssertEqual(IslandPalette(theme: .midnight, increaseContrast: false).moduleSurfaceOpacity, 0.065)
        XCTAssertEqual(IslandPalette(theme: .midnight, increaseContrast: false).moduleBorderOpacity, 0.075)
        XCTAssertEqual(IslandPalette(theme: .midnight, increaseContrast: false).ambientGlowOpacity, 0.24)
        XCTAssertEqual(IslandPalette(theme: .contrast, increaseContrast: false).ambientGlowOpacity, 0)
    }

    func testFeatureSurfacesShareTheModuleAndCompactControlTokenScale() {
        XCTAssertEqual(IslandStyle.modulePadding, 12)
        XCTAssertEqual(IslandStyle.moduleCornerRadius, 18)
        XCTAssertEqual(IslandStyle.hairlineWidth, 0.75)
        XCTAssertEqual(IslandStyle.controlHeight, 30)
        XCTAssertEqual(IslandStyle.headerControlHeight, 28)
        XCTAssertEqual(IslandStyle.minimumHitTarget, 32)
        XCTAssertEqual(IslandStyle.compactControlPadding, 8)
        XCTAssertEqual(IslandStyle.compactControlCornerRadius, 8)
        XCTAssertEqual(IslandStyle.compactControlSpacing, 8)
        XCTAssertEqual(IslandStyle.homeModuleSpacing, 8)
        XCTAssertEqual(IslandStyle.homeSectionSpacing, 8)
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

    func testPanelGeometryKeepsTheBaselineEnvelopeTopCenteredAcrossPageChanges() {
        XCTAssertEqual(preferredOpenIslandSize, CGSize(width: 640, height: 190))
        XCTAssertEqual(shadowPadding, 20)

        let panel = IslandPanelGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            panelSize: CGSize(width: 640, height: 210)
        )
        XCTAssertEqual(panel.frame, CGRect(x: 436, y: 772, width: 640, height: 210))

        // A narrow display may constrain the panel, but it remains centered
        // and attached to the display's top edge rather than a page's height.
        let constrained = IslandPanelGeometry(
            screenFrame: CGRect(x: 100, y: 50, width: 320, height: 240),
            panelSize: CGSize(width: 640, height: 210)
        )
        XCTAssertEqual(constrained.frame, CGRect(x: 100, y: 80, width: 320, height: 210))
    }

    func testNotchMetricsCoverNotchedNotchlessAndNarrowDisplays() {
        let originalNotchMode = Defaults[.notchHeightMode]
        let originalNonNotchMode = Defaults[.nonNotchHeightMode]
        defer {
            Defaults[.notchHeightMode] = originalNotchMode
            Defaults[.nonNotchHeightMode] = originalNonNotchMode
        }

        Defaults[.notchHeightMode] = .matchRealNotchSize
        let notched = NotchMetrics(input: NotchMetricsInput(
            screenFrame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_512, height: 950),
            safeAreaTop: 32,
            auxiliaryTopLeftWidth: 654,
            auxiliaryTopRightWidth: 654
        ))
        XCTAssertTrue(notched.hasPhysicalNotch)
        XCTAssertEqual(notched.physicalNotchSize, CGSize(width: 208, height: 32))
        XCTAssertEqual(notched.closedIslandSize, notched.physicalNotchSize)

        // 15-inch MacBook Air target supplied for the visual brief:
        // 2880 x 1864 physical pixels at 2x, with a 176 x 32-point notch
        // exclusion and a 1440 x 900-point uninterrupted safe canvas.
        let targetAir = NotchMetrics(input: NotchMetricsInput(
            screenFrame: CGRect(x: 0, y: 0, width: 1_440, height: 932),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            safeAreaTop: 32,
            auxiliaryTopLeftWidth: 632,
            auxiliaryTopRightWidth: 632
        ))
        XCTAssertTrue(targetAir.hasPhysicalNotch)
        XCTAssertEqual(targetAir.physicalNotchSize, CGSize(width: 180, height: 32))
        XCTAssertEqual(targetAir.openIslandSize, preferredOpenIslandSize)
        XCTAssertEqual(targetAir.panelSize, CGSize(width: 640, height: 210))

        Defaults[.nonNotchHeightMode] = .matchMenuBar
        let notchless = NotchMetrics(input: NotchMetricsInput(
            screenFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_056),
            safeAreaTop: 0,
            auxiliaryTopLeftWidth: 0,
            auxiliaryTopRightWidth: 0
        ))
        XCTAssertFalse(notchless.hasPhysicalNotch)
        XCTAssertTrue(notchless.usesSyntheticIsland)
        XCTAssertEqual(notchless.physicalNotchSize, .zero)
        XCTAssertEqual(notchless.closedIslandSize, CGSize(width: 160, height: 24))
        XCTAssertEqual(notchless.closedSurfaceSize, CGSize(width: 168, height: 24))

        // `matchRealNotchSize` existed in older defaults but has no sensible
        // meaning without a camera housing. It must remain a usable synthetic
        // island rather than falling back to an arbitrary custom value.
        Defaults[.nonNotchHeightMode] = .matchRealNotchSize
        let legacyNotchless = NotchMetrics(input: NotchMetricsInput(
            screenFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_056),
            safeAreaTop: 0,
            auxiliaryTopLeftWidth: 0,
            auxiliaryTopRightWidth: 0
        ))
        XCTAssertTrue(legacyNotchless.usesSyntheticIsland)
        XCTAssertEqual(legacyNotchless.closedIslandSize, CGSize(width: 160, height: 24))

        let narrow = NotchMetrics(input: NotchMetricsInput(
            screenFrame: CGRect(x: 0, y: 0, width: 320, height: 240),
            visibleFrame: CGRect(x: 0, y: 0, width: 320, height: 216),
            safeAreaTop: 0,
            auxiliaryTopLeftWidth: 0,
            auxiliaryTopRightWidth: 0
        ))
        XCTAssertLessThanOrEqual(narrow.openIslandSize.width, 304)
        XCTAssertLessThanOrEqual(narrow.openIslandSize.height, 192)
    }

    func testClosedBridgeAndHoverTargetStayOutsideThePhysicalCameraGeometry() {
        let originalHoverSetting = Defaults[.extendHoverArea]
        defer { Defaults[.extendHoverArea] = originalHoverSetting }

        let metrics = NotchMetrics(input: NotchMetricsInput(
            screenFrame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_512, height: 950),
            safeAreaTop: 32,
            auxiliaryTopLeftWidth: 654,
            auxiliaryTopRightWidth: 654
        ))

        XCTAssertEqual(metrics.physicalNotchSize, CGSize(width: 208, height: 32))
        XCTAssertEqual(metrics.closedSurfaceSize, CGSize(width: 216, height: 32))
        XCTAssertEqual(metrics.hoverHitFrame, CGRect(x: 648, y: 950, width: 216, height: 32))

        Defaults[.extendHoverArea] = true
        XCTAssertEqual(metrics.hoverHitFrame, CGRect(x: 618, y: 920, width: 276, height: 62))
        XCTAssertTrue(metrics.containsHoverPoint(CGPoint(x: 630, y: 930)))
        XCTAssertFalse(metrics.containsHoverPoint(CGPoint(x: 617.9, y: 930)))
        XCTAssertFalse(metrics.containsHoverPoint(CGPoint(x: 756, y: 982)))
    }

    func testClosedMediaActivityKeepsArtworkAndVisualizerOutsideTheHardwareBridge() {
        let layout = ClosedMediaActivityGeometry(
            physicalBridgeWidth: 208,
            closedHeight: 32
        )

        XCTAssertEqual(layout.bridgeWidth, 208)
        XCTAssertEqual(layout.wingWidth, 20)
        XCTAssertEqual(layout.totalWidth, 248)
        XCTAssertEqual(
            layout.totalWidth + cornerRadiusInsets.closed.bottom * 2,
            276
        )
    }

    func testClosedTimerActivityStaysCompactWhileAccommodatingControls() {
        let narrowBridge = ClosedTimerActivityGeometry(physicalBridgeWidth: 120)
        XCTAssertEqual(narrowBridge.contentWidth, 176)

        let notchedBridge = ClosedTimerActivityGeometry(physicalBridgeWidth: 208)
        XCTAssertEqual(notchedBridge.contentWidth, 208)
        XCTAssertEqual(ClosedTimerActivityGeometry.controlHeight, 32)
        XCTAssertEqual(ClosedTimerActivityGeometry.bottomInset, 6)
    }

    func testPausedTrackRemainsPresentable() {
        let paused = PlaybackState(
            bundleIdentifier: "com.apple.Music",
            isPlaying: false,
            title: "Track",
            artist: "Artist"
        )
        XCTAssertTrue(MediaPresentationPolicy.hasTrack(paused))
        XCTAssertFalse(MediaPresentationPolicy.isIdle(paused))

        let noTrack = PlaybackState(bundleIdentifier: "com.apple.Music")
        XCTAssertFalse(MediaPresentationPolicy.hasTrack(noTrack))
        XCTAssertTrue(MediaPresentationPolicy.isIdle(noTrack))
    }

    func testHomeLayoutBudgetKeepsMediaPrimaryAndBoundsOptionalModules() {
        XCTAssertEqual(
            IslandStyle.homeContentSize(
                openIslandSize: CGSize(width: 600, height: 300),
                headerHeight: 32
            ),
            CGSize(width: 538, height: 248)
        )

        let openIsland = CGSize(width: 640, height: 190)
        let expandedPage = IslandStyle.expandedPageSize(
            openIslandSize: openIsland,
            headerHeight: 32
        )
        let homeContent = IslandStyle.homeContentSize(
            openIslandSize: openIsland,
            headerHeight: 32
        )
        XCTAssertEqual(expandedPage, CGSize(width: 578, height: 138))
        XCTAssertEqual(homeContent, expandedPage)
        XCTAssertEqual(
            32 + IslandStyle.headerContentSpacing + homeContent.height + IslandStyle.homeTopInset
                + IslandStyle.homeBottomInset + IslandStyle.openSurfacePadding,
            openIsland.height
        )

        let full = HomeLayoutBudget(
            availableSize: CGSize(width: 592, height: 140),
            wantsCalendar: true,
            wantsCamera: true,
            showsWeather: false
        )
        XCTAssertEqual(full.mediaWidth, 286)
        XCTAssertEqual(full.calendarWidth, 178)
        XCTAssertEqual(full.cameraSize, CGSize(width: 112, height: 112))
        XCTAssertLessThanOrEqual(full.mediaWidth + full.occupiedWidth, full.availableSize.width)

        let weather = HomeLayoutBudget(
            availableSize: CGSize(width: 592, height: 140),
            wantsCalendar: true,
            wantsCamera: true,
            showsWeather: true
        )
        XCTAssertEqual(weather.moduleHeight, 104)
        XCTAssertEqual(weather.cameraSize, CGSize(width: 112, height: 104))

        let narrow = HomeLayoutBudget(
            availableSize: CGSize(width: 296, height: 140),
            wantsCalendar: true,
            wantsCamera: true,
            showsWeather: false
        )
        XCTAssertEqual(narrow.mediaWidth, 296)
        XCTAssertNil(narrow.calendarWidth)
        XCTAssertNil(narrow.cameraSize)

        let short = HomeLayoutBudget(
            availableSize: CGSize(width: 592, height: 80),
            wantsCalendar: true,
            wantsCamera: true,
            showsWeather: false
        )
        XCTAssertEqual(short.calendarWidth, 215)
        XCTAssertNil(short.cameraSize)
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

    func testDeniedCalendarAndCameraPoliciesKeepProtectedContentUnavailable() {
        XCTAssertFalse(CalendarAccessPolicy.hasReadAccess(.denied))
        XCTAssertFalse(CalendarAccessPolicy.hasReadAccess(.restricted))
        XCTAssertTrue(CalendarAccessPolicy.shouldClearEvents(
            calendarStatus: .denied,
            reminderStatus: .restricted
        ))
        XCTAssertFalse(CalendarAccessPolicy.shouldClearEvents(
            calendarStatus: .fullAccess,
            reminderStatus: .denied
        ))

        XCTAssertFalse(CameraPreviewPolicy.canStart(
            authorizationStatus: .denied,
            cameraAvailable: true
        ))
        XCTAssertFalse(CameraPreviewPolicy.canStart(
            authorizationStatus: .authorized,
            cameraAvailable: false
        ))
        XCTAssertTrue(CameraPreviewPolicy.canStart(
            authorizationStatus: .authorized,
            cameraAvailable: true
        ))
    }

    func testMirrorPresentationExplainsUnavailableAndPermissionStates() {
        XCTAssertEqual(MirrorPresentation.toggledShape(from: .circle), .rectangle)
        XCTAssertEqual(MirrorPresentation.toggledShape(from: .rectangle), .circle)
        XCTAssertEqual(
            MirrorPresentation.status(
                isRunning: false,
                cameraAvailable: false,
                authorizationStatus: .authorized,
                managerMessage: nil
            ),
            "No camera available"
        )
        XCTAssertEqual(
            MirrorPresentation.status(
                isRunning: false,
                cameraAvailable: true,
                authorizationStatus: .notDetermined,
                managerMessage: nil
            ),
            "Camera access will be requested when opened"
        )
        XCTAssertEqual(
            MirrorPresentation.status(
                isRunning: false,
                cameraAvailable: true,
                authorizationStatus: .denied,
                managerMessage: nil
            ),
            "Camera access is required"
        )
    }

    func testUnavailableXPCServiceFailsClosed() async {
        let client = XPCHelperClient(serviceName: "com.macisland.tests.unavailable.\(UUID().uuidString)")

        let authorized = await client.isAccessibilityAuthorized()
        XCTAssertFalse(authorized)
        XCTAssertEqual(client.connectionState, .unavailable)
        XCTAssertFalse(client.accessibilityAuthorized)
    }

    func testManualLocationLookupRejectsEmptyAndDeniedResponses() async {
        let emptyResults: WeatherDataLoader = { url in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(#"{"results":[]}"#.utf8), response)
        }
        let denied: WeatherDataLoader = { _ in throw URLError(.userAuthenticationRequired) }

        do {
            _ = try await BoringViewCoordinator.resolveWeatherLocation(named: "Nowhere", dataLoader: emptyResults)
            XCTFail("Expected an empty manual-location response to fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .cannotFindHost)
        }
        do {
            _ = try await BoringViewCoordinator.resolveWeatherLocation(named: "Austin", dataLoader: denied)
            XCTFail("Expected a denied manual-location response to fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .userAuthenticationRequired)
        }
    }

    func testWeatherLocationRequestDefaultsToCurrentLocationUnlessACustomCityIsChosen() {
        XCTAssertEqual(
            WeatherLocationRequest(mode: .automatic, cityQuery: "Austin"),
            .currentLocation
        )
        XCTAssertEqual(
            WeatherLocationRequest(mode: .custom, cityQuery: "  Austin  "),
            .city("Austin")
        )
        XCTAssertNil(WeatherLocationRequest(mode: .custom, cityQuery: "   "))
    }

    func testDisplayRemovalAndSleepWakePoliciesFailSafe() {
        XCTAssertEqual(
            AppLifecyclePolicy.detachedDisplayIdentifiers(
                existing: ["built-in", "external"],
                current: ["built-in"]
            ),
            ["external"]
        )
        XCTAssertFalse(AppLifecyclePolicy.shouldMonitorDragDetection(enabled: true, isScreenLocked: true))
        XCTAssertFalse(AppLifecyclePolicy.shouldMonitorDragDetection(enabled: false, isScreenLocked: false))
        XCTAssertTrue(AppLifecyclePolicy.shouldMonitorDragDetection(enabled: true, isScreenLocked: false))
        XCTAssertFalse(AppLifecyclePolicy.shouldResumeCameraAfterWake(isMirrorExpanded: false))
        XCTAssertTrue(AppLifecyclePolicy.shouldResumeCameraAfterWake(isMirrorExpanded: true))

        let viewModel = BoringViewModel()
        defer { viewModel.destroy() }
        viewModel.setScreenLocked(true)
        viewModel.setScreenLocked(false)
        viewModel.open()
        XCTAssertEqual(viewModel.notchState, .open)
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

    func testCountdownCompletionPersistsUntilDismissed() async throws {
        let coordinator = BoringViewCoordinator.shared
        let originalNotifications = Defaults[.timerCompletionNotifications]
        TimerCompletionFeedback.suppressPlaybackForTesting = true
        Defaults[.timerCompletionNotifications] = false
        defer {
            TimerCompletionFeedback.suppressPlaybackForTesting = false
            Defaults[.timerCompletionNotifications] = originalNotifications
            coordinator.stopTimer()
        }

        coordinator.startTimer(seconds: 1)
        try await Task.sleep(for: .milliseconds(1_250))

        XCTAssertEqual(coordinator.timerStatus, .completed)
        XCTAssertEqual(coordinator.timerRemaining, 0)

        coordinator.stopTimer()
        XCTAssertEqual(coordinator.timerStatus, .idle)
    }

    func testTimerCompletionResumesOnlyTheMediaSourceItPaused() {
        let paused = TimerPausedMedia(
            source: .spotify,
            bundleIdentifier: "com.spotify.client"
        )

        XCTAssertTrue(TimerCompletionMediaPolicy.shouldResume(
            pausedMedia: paused,
            currentSource: .spotify,
            currentBundleIdentifier: "com.spotify.client"
        ))
        XCTAssertFalse(TimerCompletionMediaPolicy.shouldResume(
            pausedMedia: paused,
            currentSource: .appleMusic,
            currentBundleIdentifier: "com.apple.Music"
        ))
        XCTAssertFalse(TimerCompletionMediaPolicy.shouldResume(
            pausedMedia: paused,
            currentSource: .spotify,
            currentBundleIdentifier: "com.spotify.other"
        ))
    }

    func testPersistedCountdownRecoveryHonorsElapsedAndPausedTime() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let running = PersistedCountdownTimer.running(until: now.addingTimeInterval(90))
        XCTAssertEqual(running.remaining(at: now.addingTimeInterval(30)), 60)
        XCTAssertEqual(running.remaining(at: now.addingTimeInterval(100)), 0)

        let paused = PersistedCountdownTimer.paused(remaining: 45)
        XCTAssertEqual(paused.remaining(at: now.addingTimeInterval(10_000)), 45)

        let encoded = try? JSONEncoder().encode(paused)
        XCTAssertEqual(encoded.flatMap { try? JSONDecoder().decode(PersistedCountdownTimer.self, from: $0) }, paused)
    }

    func testTimerNotificationUsesStableIdentifierAndNativeContent() {
        let content = TimerCompletionNotification.content()
        XCTAssertEqual(TimerCompletionNotification.identifier, "macisland.countdown-complete")
        XCTAssertEqual(content.title, "Timer finished")
        XCTAssertEqual(content.sound, .default)
        XCTAssertTrue(TimerCompletionNotification.presentationOptions.contains(.banner))
        XCTAssertTrue(TimerCompletionNotification.presentationOptions.contains(.list))
        XCTAssertTrue(TimerCompletionNotification.presentationOptions.contains(.sound))
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

    func testWeatherCacheUsesOnlyTheCurrentCityWithinItsLifetime() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = WeatherSnapshot(
            location: " Austin ",
            temperatureCelsius: 20,
            weatherCode: 0,
            updatedAt: now.addingTimeInterval(-60)
        )

        XCTAssertTrue(BoringViewCoordinator.isWeatherCacheFresh(
            snapshot,
            for: "austin",
            now: now,
            lifetime: 15 * 60
        ))
        XCTAssertFalse(BoringViewCoordinator.isWeatherCacheFresh(
            snapshot,
            for: "Chicago",
            now: now,
            lifetime: 15 * 60
        ))
        XCTAssertFalse(BoringViewCoordinator.isWeatherCacheFresh(
            snapshot,
            for: "Austin",
            now: now.addingTimeInterval(15 * 60),
            lifetime: 15 * 60
        ))
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

    func testActivityCoordinatorReplaysSuppressedWorkAfterPriorityHandoff() {
        let coordinator = BoringViewCoordinator.shared
        defer {
            coordinator.toggleSneakPeek(status: false, type: .music)
            coordinator.toggleExpandingView(status: false, type: .battery)
        }

        coordinator.toggleSneakPeek(status: true, type: .music, duration: 60)
        coordinator.toggleExpandingView(status: true, type: .download)
        XCTAssertTrue(coordinator.expandingView.show)
        XCTAssertEqual(coordinator.expandingView.type, .download)
        XCTAssertFalse(coordinator.sneakPeek.show)

        // Music is blocked by Download and queued. Battery preempts Download;
        // the queued music must not flash during the handoff.
        coordinator.toggleSneakPeek(status: true, type: .music, duration: 60)
        coordinator.toggleExpandingView(status: true, type: .battery)
        XCTAssertTrue(coordinator.expandingView.show)
        XCTAssertEqual(coordinator.expandingView.type, .battery)
        XCTAssertFalse(coordinator.sneakPeek.show)

        coordinator.toggleExpandingView(status: false, type: .battery)
        XCTAssertTrue(coordinator.sneakPeek.show)
        XCTAssertEqual(coordinator.sneakPeek.type, .music)
    }

    func testIslandSceneResolverKeepsUserAndCriticalActivityPriority() {
        let allVisible = IslandSceneInput(
            isOnboarding: false,
            isOpen: false,
            currentView: .home,
            isBatteryActivityVisible: true,
            isSystemHUDVisible: true,
            isTimerVisible: true,
            isTimerCompleted: true,
            isMediaVisible: true,
            isIdleFaceVisible: true
        )
        XCTAssertEqual(IslandSceneResolver.resolve(allVisible), .battery)

        let openShelf = IslandSceneInput(
            isOnboarding: false,
            isOpen: true,
            currentView: .shelf,
            isBatteryActivityVisible: true,
            isSystemHUDVisible: true,
            isTimerVisible: true,
            isTimerCompleted: true,
            isMediaVisible: true,
            isIdleFaceVisible: true
        )
        XCTAssertEqual(IslandSceneResolver.resolve(openShelf), .shelf)

        let timerOverMedia = IslandSceneInput(
            isOnboarding: false,
            isOpen: false,
            currentView: .home,
            isBatteryActivityVisible: false,
            isSystemHUDVisible: false,
            isTimerVisible: true,
            isTimerCompleted: false,
            isMediaVisible: true,
            isIdleFaceVisible: true
        )
        XCTAssertEqual(IslandSceneResolver.resolve(timerOverMedia), .timer)

        let completedTimerOverHUD = IslandSceneInput(
            isOnboarding: false,
            isOpen: false,
            currentView: .home,
            isBatteryActivityVisible: false,
            isSystemHUDVisible: true,
            isTimerVisible: true,
            isTimerCompleted: true,
            isMediaVisible: true,
            isIdleFaceVisible: true
        )
        XCTAssertEqual(IslandSceneResolver.resolve(completedTimerOverHUD), .timer)

        let activeTimerOverHUD = IslandSceneInput(
            isOnboarding: false,
            isOpen: false,
            currentView: .home,
            isBatteryActivityVisible: false,
            isSystemHUDVisible: true,
            isTimerVisible: true,
            isTimerCompleted: false,
            isMediaVisible: true,
            isIdleFaceVisible: true
        )
        XCTAssertEqual(IslandSceneResolver.resolve(activeTimerOverHUD), .systemHUD)
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

    func testCopyClipboardEntryWritesPlainTextWithoutCapturingIt() {
        let coordinator = BoringViewCoordinator.shared
        let originalEnabled = Defaults[.clipboardHistoryEnabled]
        Defaults[.clipboardHistoryEnabled] = true
        defer {
            coordinator.clearClipboardHistory()
            Defaults[.clipboardHistoryEnabled] = originalEnabled
        }

        coordinator.clearClipboardHistory()
        coordinator.copyClipboardEntry(ClipboardEntry(text: "copy this snippet"))

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "copy this snippet")
        XCTAssertTrue(coordinator.clipboardEntries.isEmpty)
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

    func testSharingInteractionPolicyKeepsIslandContextAcrossNativeHandoffs() {
        XCTAssertTrue(SharingInteractionPolicy.shouldTransferFilePickerLease(
            response: .OK,
            selectedItemCount: 1
        ))
        XCTAssertFalse(SharingInteractionPolicy.shouldTransferFilePickerLease(
            response: .cancel,
            selectedItemCount: 1
        ))
        XCTAssertFalse(SharingInteractionPolicy.shouldTransferFilePickerLease(
            response: .OK,
            selectedItemCount: 0
        ))
        XCTAssertTrue(SharingInteractionPolicy.canPresentSystemPicker(from: NSView()))
        XCTAssertFalse(SharingInteractionPolicy.canPresentSystemPicker(from: nil))
    }

    func testQuickLookKeepsRegularFileURLsWithoutSecurityScope() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("macisland-quick-look-\(UUID().uuidString).txt")
        try Data("Shelf preview".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = QuickLookService()
        service.show(urls: [url])

        XCTAssertEqual(service.urls, [url])
        XCTAssertEqual(service.selectedURL, url)
        XCTAssertTrue(service.isQuickLookOpen)

        service.hide()
        XCTAssertFalse(service.isQuickLookOpen)
    }

    func testTemporaryFileNamesCannotEscapeTheirGeneratedDirectory() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("macisland-temp-name-test", isDirectory: true)

        let traversal = TemporaryFileStorageService.safeChildURL(
            in: directory,
            suggestedName: "../../audit-target",
            fallbackName: "item.dat"
        )
        XCTAssertEqual(traversal.deletingLastPathComponent().standardizedFileURL, directory.standardizedFileURL)
        XCTAssertEqual(traversal.lastPathComponent, "audit-target")

        XCTAssertEqual(
            TemporaryFileStorageService.safeFilename("..", fallbackName: "item.dat"),
            "item.dat"
        )
        XCTAssertEqual(
            TemporaryFileStorageService.safeFilename("report/\\0?.txt", fallbackName: "item.dat"),
            "0_.txt"
        )
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
