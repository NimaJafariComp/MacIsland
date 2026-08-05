// MacIsland is derived from Boring Notch.
// Original copyright remains with Boring Notch contributors.

import AVFoundation
import AppKit
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI

enum UIAuditState: String, CaseIterable, Equatable {
    case closed
    case hover
    case home
    case shelf
    case timer
    case media
    case mediaPlaying
    case mediaPaused
    case camera
    case error
    case accessibility
    case calendarStress
    case calendarHomeStress
    case snippetsStress
    case snippetsEmpty

    init(argument: String) {
        switch argument.lowercased() {
        case "dismissed": self = .closed
        case "expanded": self = .home
        case "media-playing": self = .mediaPlaying
        case "media-paused": self = .mediaPaused
        case "calendar-stress", "calendar": self = .calendarStress
        case "calendar-home-stress", "calendar-home": self = .calendarHomeStress
        case "snippets-stress", "snippets": self = .snippetsStress
        case "snippets-empty", "empty-snippets": self = .snippetsEmpty
        default: self = UIAuditState(rawValue: argument.lowercased()) ?? .closed
        }
    }

    init?(shortcut: String) {
        let shortcuts: [String: UIAuditState] = [
            "1": .closed, "2": .hover, "3": .home, "4": .shelf, "5": .timer,
            "6": .media, "7": .camera, "8": .error, "9": .accessibility,
        ]
        guard let state = shortcuts[shortcut] else { return nil }
        self = state
    }
}

enum UIAuditMode {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-uiAuditMode")

    static let launchState: UIAuditState = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uiAuditState"),
              arguments.indices.contains(index + 1)
        else { return .closed }
        return UIAuditState(argument: arguments[index + 1])
    }()
}

/// Deliberately varied in-memory Calendar content for visual QA. Nothing here
/// is written to EventKit or Defaults, and it is only installed by
/// `UIAuditState.calendarStress`.
@MainActor
private enum UIAuditFixtures {
    /// Keep an audit run internally consistent if UI state is re-applied after
    /// midnight. Production events come from EventKit; this only stabilizes
    /// synthetic QA data for the lifetime of an audit process.
    static let sessionReferenceDate = Date()

    static let clipboardEntries = [
        "Meeting notes: confirm product launch milestones and owner assignments.",
        "ssh deploy@production.example.com",
        "A deliberately long snippet for exercising two-line clipping and panel growth in the Snippets page.",
        "Design review agenda",
        "https://macisland.app/release-notes",
        "Follow up with the team after the Calendar usability test.",
        "git status --short",
        "Remember to archive completed work only after final verification.",
        "Customer interview highlights: onboarding completion improved after the new permission sequence.",
        "https://developer.apple.com/documentation/eventkit",
        "Ship checklist: validate signing, notarization, first-launch onboarding, and update path.",
        "Design note: keep the notch surface calm while preserving a 44-point minimum target.",
        "SELECT id, title, updated_at FROM release_notes ORDER BY updated_at DESC;",
        "Reminder: send the accessibility review summary before tomorrow's design stand-up.",
        "A second intentionally long audit snippet verifies truncation remains legible in the capped scroll surface.",
        "https://support.apple.com/guide/mac-help/change-battery-settings-mchleab3a043/mac",
        "Terminal command: xcodebuild -scheme MacIsland -configuration Debug build",
        "Pairing notes: check Bluetooth route handoff after reconnecting external headphones.",
        "The quick brown fox jumps over the lazy dog — typography and line-break regression sample.",
        "Product copy draft: Your most useful Mac controls, always within reach.",
        "https://macisland.app/privacy",
        "Keep this item to exercise a full final grid row in the Snippets audit.",
        "Release candidate 4: media, calendar, mirror, Shelf, and battery visual checks complete.",
        "One final compact text entry for scrollbar and content-height verification.",
    ].map { ClipboardEntry(text: $0) }

    /// A dense, mixed Shelf workload. Text and link items are intentionally
    /// self-contained: audit mode must not create bookmarks or touch user files.
    static let shelfItems: [ShelfItem] = [
        .init(kind: .text(string: "Product launch checklist")),
        .init(kind: .link(url: URL(string: "https://www.apple.com/mac/")!)),
        .init(kind: .text(string: "Design review notes — final draft")),
        .init(kind: .link(url: URL(string: "https://developer.apple.com/documentation/swiftui")!)),
        .init(kind: .text(string: "ssh deploy@staging.example.com")),
        .init(kind: .link(url: URL(string: "https://github.com/MacIsland/MacIsland/pulls")!)),
        .init(kind: .text(string: "Travel itinerary: Austin → San Francisco")),
        .init(kind: .link(url: URL(string: "https://calendar.apple.com/")!)),
        .init(kind: .text(string: "Quarterly planning presentation with a deliberately long title")),
        .init(kind: .link(url: URL(string: "https://www.figma.com/files/recent")!)),
        .init(kind: .text(string: "Customer research: interview highlights")),
        .init(kind: .link(url: URL(string: "https://www.notion.so/workspace")!)),
        .init(kind: .text(string: "Meeting recording follow-up")),
        .init(kind: .link(url: URL(string: "https://slack.com/app_redirect?channel=design")!)),
        .init(kind: .text(string: "Release candidate validation steps")),
        .init(kind: .link(url: URL(string: "https://support.apple.com/macos")!)),
        .init(kind: .text(string: "One more compact text item")),
        .init(kind: .link(url: URL(string: "https://macisland.app/release-notes")!)),
    ]

    static func calendarItems(
        reference: Date? = nil,
        omittingAllDay: Bool = false,
        longFirstTimedTitle: Bool = false
    ) -> [EventModel] {
        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: reference ?? sessionReferenceDate)
        let work = CalendarModel(
            id: "audit-work",
            account: "MacIsland QA",
            title: "Work",
            color: .systemBlue,
            isSubscribed: false,
            isReminder: false
        )
        let personal = CalendarModel(
            id: "audit-personal",
            account: "MacIsland QA",
            title: "Personal",
            color: .systemPurple,
            isSubscribed: false,
            isReminder: false
        )
        let reminders = CalendarModel(
            id: "audit-reminders",
            account: "MacIsland QA",
            title: "Reminders",
            color: .systemOrange,
            isSubscribed: false,
            isReminder: true
        )

        func item(
            _ id: String,
            _ title: String,
            dayOffset: Int = 0,
            hour: Int? = nil,
            minute: Int = 0,
            duration: Int = 30,
            type: EventType = .event(.accepted),
            calendar source: CalendarModel
        ) -> EventModel {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday)!
            let start = hour.map {
                calendar.date(bySettingHour: $0, minute: minute, second: 0, of: day)!
            } ?? day
            let isAllDay = hour == nil
            return EventModel(
                id: id,
                start: start,
                end: isAllDay ? calendar.date(byAdding: .day, value: 1, to: start)! : start.addingTimeInterval(TimeInterval(duration * 60)),
                title: title,
                location: nil,
                notes: nil,
                url: nil,
                isAllDay: isAllDay,
                type: type,
                calendar: source,
                participants: [],
                timeZone: .autoupdatingCurrent,
                hasRecurrenceRules: false,
                priority: nil
            )
        }

        let items = [
            // After midnight, Home advances to the new day while the prior day
            // remains selectable in the full-calendar wheel.
            item("audit-yesterday-wrap", "Release retrospective", dayOffset: -1, hour: 9, duration: 45, calendar: work),
            item("audit-yesterday-dinner", "Dinner with family", dayOffset: -1, hour: 18, minute: 30, duration: 90, calendar: personal),
            item("audit-yesterday-reminder", "Submit expense report", dayOffset: -1, hour: 20, type: .reminder(completed: false), calendar: reminders),
            item("audit-all-day", "Company offsite — all day", type: .event(.accepted), calendar: work),
            item(
                "audit-review",
                longFirstTimedTitle
                    ? "Quarterly planning workshop with a deliberately long title for Home truncation"
                    : "Design review: Calendar layout and compact density",
                hour: 8,
                minute: 30,
                duration: 45,
                calendar: work
            ),
            item("audit-overlap-a", "Team stand-up", hour: 9, duration: 30, calendar: work),
            item("audit-overlap-b", "Doctor appointment", hour: 9, minute: 15, duration: 45, calendar: personal),
            item("audit-long", "Quarterly planning workshop with a deliberately long title for truncation", hour: 10, duration: 90, calendar: work),
            item("audit-lunch", "Lunch with Maya", hour: 12, duration: 60, calendar: personal),
            item("audit-reminder", "Pick up package before 5 PM", hour: 16, type: .reminder(completed: false), calendar: reminders),
            item("audit-followup", "Send project follow-up", hour: 17, minute: 30, type: .reminder(completed: false), calendar: reminders),
            item("audit-completed", "Completed reminder remains visible when enabled", hour: 18, type: .reminder(completed: true), calendar: reminders),
            item("audit-next-all-day", "Conference day", dayOffset: 1, calendar: work),
            item("audit-next-planning", "Roadmap planning", dayOffset: 1, hour: 9, duration: 60, calendar: work),
            item("audit-next-review", "Design critique", dayOffset: 1, hour: 11, minute: 30, calendar: personal),
            item("audit-next-reminder", "Send invoices", dayOffset: 1, hour: 15, type: .reminder(completed: false), calendar: reminders),
            item("audit-later-sync", "Partner sync", dayOffset: 2, hour: 8, minute: 30, calendar: work),
            item("audit-later-write", "Write release notes", dayOffset: 2, hour: 10, duration: 60, calendar: work),
            item("audit-later-reminder", "Review pull requests", dayOffset: 2, hour: 14, type: .reminder(completed: false), calendar: reminders),
            item("audit-final-standup", "Team stand-up", dayOffset: 3, hour: 9, calendar: work),
            item("audit-final-dinner", "Dinner reservation", dayOffset: 3, hour: 19, calendar: personal),
            item("audit-final-reminder", "Pack for trip", dayOffset: 3, hour: 20, type: .reminder(completed: false), calendar: reminders),
        ]
        return omittingAllDay ? items.filter { !$0.isAllDay } : items
    }
}

@MainActor
final class UIAuditController: ObservableObject {
    static let shared = UIAuditController()

    @Published private(set) var state = UIAuditMode.launchState

    func select(_ state: UIAuditState) {
        self.state = state
    }
}

@main
struct MacIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Default(.menubarIcon) var showMenuBarIcon

    init() {
        SettingsMigration.apply()
    }

    var body: some Scene {
        MenuBarExtra("MacIsland", systemImage: "sparkle", isInserted: $showMenuBarIcon) {
            Menu("Mirror") {
                Button("Open Mirror") {
                    NotificationCenter.default.post(name: .openMirrorRequested, object: nil)
                }
                Button("Close Mirror") {
                    NotificationCenter.default.post(name: .closeMirrorRequested, object: nil)
                }
            }
            Button("Settings") {
                DispatchQueue.main.async {
                    SettingsWindowController.shared.showWindow()
                }
            }
            .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            Divider()
            Button("Restart MacIsland") {
                ApplicationRelauncher.restart()
            }
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(self)
            }
            .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windows: [String: NSWindow] = [:] // UUID -> NSWindow
    var viewModels: [String: BoringViewModel] = [:] // UUID -> BoringViewModel
    var window: NSWindow?
    let vm: BoringViewModel = .init()
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    var quickShareService = QuickShareService.shared
    var whatsNewWindow: NSWindow?
    var timer: Timer?
    var closeNotchTask: Task<Void, Never>?
    private var previousScreens: [NSScreen]?
    private var onboardingWindowController: NSWindowController?
    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?
    private var workspaceWakeObserver: Any?
    private var workspaceSleepObserver: Any?
    private var escapeKeyMonitor: Any?
    private var localEscapeKeyMonitor: Any?
    private var uiAuditKeyMonitor: Any?
    private var uiAuditState: UIAuditState = UIAuditMode.launchState
    private var isScreenLocked: Bool = false
    private var windowScreenDidChangeObserver: Any?
    private var dragDetectors: [String: DragDetector] = [:] // UUID -> DragDetector
    private var notificationObservers: [NSObjectProtocol] = []
    private var pendingPanelResize: DispatchWorkItem?
    private var unlockTransitionTask: Task<Void, Never>?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        WebcamManager.shared.refreshAuthorizationStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        notificationObservers.removeAll()
        if let observer = screenLockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenLockedObserver = nil
        }
        if let observer = screenUnlockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockedObserver = nil
        }
        if let observer = workspaceWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceWakeObserver = nil
        }
        if let observer = workspaceSleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceSleepObserver = nil
        }
        if let escapeKeyMonitor {
            NSEvent.removeMonitor(escapeKeyMonitor)
            self.escapeKeyMonitor = nil
        }
        if let localEscapeKeyMonitor {
            NSEvent.removeMonitor(localEscapeKeyMonitor)
            self.localEscapeKeyMonitor = nil
        }
        if let uiAuditKeyMonitor {
            NSEvent.removeMonitor(uiAuditKeyMonitor)
            self.uiAuditKeyMonitor = nil
        }
        MusicManager.shared.destroy()
        WebcamManager.shared.stopSession()
        CalendarManager.shared.shutdown()
        BatteryActivityManager.shared.shutdown()
        closeNotchTask?.cancel()
        unlockTransitionTask?.cancel()
        coordinator.setSystemStatesSuspended(true)
        cleanupDragDetectors()
        cleanupWindows()
        XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
    }

    @MainActor
    func onScreenLocked(_ notification: Notification) {
        isScreenLocked = true
        setScreenLockState(true)
        WebcamManager.shared.stopSession()
        cleanupDragDetectors()
        if !Defaults[.showOnLockScreen] {
            cleanupWindows()
        } else {
            enableSkyLightOnAllWindows()
        }
    }

    @MainActor
    func onScreenUnlocked(_ notification: Notification) {
        isScreenLocked = false
        setScreenLockState(false)
        setupDragDetectors()
        if !Defaults[.showOnLockScreen] {
            adjustWindowPosition(changeAlpha: true)
        } else {
            disableSkyLightOnAllWindows()
        }
    }

    @MainActor
    private func setScreenLockState(_ locked: Bool) {
        vm.setScreenLocked(locked)
        viewModels.values.forEach { $0.setScreenLocked(locked) }

        if locked {
            coordinator.dismissTransientActivitiesForLock()
        }
        coordinator.setSystemStatesSuspended(locked)
    }
    
    @MainActor
    private func enableSkyLightOnAllWindows() {
        if Defaults[.showOnAllDisplays] {
            windows.values.forEach { window in
                if let skyWindow = window as? BoringNotchSkyLightWindow {
                    skyWindow.enableSkyLight()
                }
            }
        } else {
            if let skyWindow = window as? BoringNotchSkyLightWindow {
                skyWindow.enableSkyLight()
            }
        }
    }
    
    @MainActor
    private func disableSkyLightOnAllWindows() {
        // Delay disabling SkyLight to avoid flicker during unlock transition
        unlockTransitionTask?.cancel()
        unlockTransitionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                if Defaults[.showOnAllDisplays] {
                    self.windows.values.forEach { window in
                        if let skyWindow = window as? BoringNotchSkyLightWindow {
                            skyWindow.disableSkyLight()
                        }
                    }
                } else {
                    if let skyWindow = self.window as? BoringNotchSkyLightWindow {
                        skyWindow.disableSkyLight()
                    }
                }
            }
        }
    }

    private func cleanupWindows(shouldInvert: Bool = false) {
        let shouldCleanupMulti = shouldInvert ? !Defaults[.showOnAllDisplays] : Defaults[.showOnAllDisplays]
        
        if shouldCleanupMulti {
            windows.values.forEach { window in
                window.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(window)
            }
            windows.removeAll()
            viewModels.removeAll()
        } else if let window = window {
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
            if let obs = windowScreenDidChangeObserver {
                NotificationCenter.default.removeObserver(obs)
                windowScreenDidChangeObserver = nil
            }
            self.window = nil
        }
    }

    private func cleanupDragDetectors() {
        dragDetectors.values.forEach { detector in
            detector.stopMonitoring()
        }
        dragDetectors.removeAll()
    }

    private func setupDragDetectors() {
        cleanupDragDetectors()

        guard AppLifecyclePolicy.shouldMonitorDragDetection(
            enabled: Defaults[.expandedDragDetection],
            isScreenLocked: isScreenLocked
        ) else { return }

        if Defaults[.showOnAllDisplays] {
            for screen in NSScreen.screens {
                setupDragDetectorForScreen(screen)
            }
        } else {
            let preferredScreen: NSScreen? = window?.screen
                ?? NSScreen.screen(withUUID: coordinator.selectedScreenUUID)
                ?? NSScreen.main

            if let screen = preferredScreen {
                setupDragDetectorForScreen(screen)
            }
        }
    }

    private func setupDragDetectorForScreen(_ screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }
        
        let metrics = NotchMetrics(screen: screen)
        let screenFrame = metrics.screenFrame
        let notchHeight = metrics.dragTargetSize.height
        let notchWidth = metrics.dragTargetSize.width
        
        // Create notch region at the top-center of the screen where an open notch would occupy
        let notchRegion = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        
        let detector = DragDetector(notchRegion: notchRegion)
        
        detector.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                self?.handleDragEntersNotchRegion(onScreen: screen)
            }
        }
        
        dragDetectors[uuid] = detector
        detector.startMonitoring()
    }

    private func handleDragEntersNotchRegion(onScreen screen: NSScreen) {
        guard !isScreenLocked else { return }
        guard let uuid = screen.displayUUID else { return }
        
        if Defaults[.showOnAllDisplays], let viewModel = viewModels[uuid] {
            viewModel.open()
            coordinator.currentView = .shelf
        } else if !Defaults[.showOnAllDisplays], let windowScreen = window?.screen, screen == windowScreen {
            vm.open()
            coordinator.currentView = .shelf
        }
    }

    private func createBoringNotchWindow(for screen: NSScreen, with viewModel: BoringViewModel) -> NSWindow {
        viewModel.updateMetrics()
        let geometry = IslandPanelGeometry(screenFrame: screen.frame, panelSize: viewModel.panelSize)
        // Give AppKit the final top-centre frame from the outset. Previously
        // this panel was born at (0, 0) and relied on a later lifecycle pass
        // to move it to the notch. If that pass raced display restoration, a
        // live MacIsland process could remain invisible at the bottom-left.
        let rect = geometry.frame
        // The Island is visually borderless, but it is also a real interactive
        // surface. Utility/HUD panel styles can reject text-system activation
        // even when canBecomeKey is overridden.
        let styleMask: NSWindow.StyleMask = [.borderless]
        
        // SkyLight panels are intentionally treated as overlays by macOS and
        // can be absent from both accessibility and framebuffer capture. Audit
        // mode needs an ordinary panel so Computer Use can inspect the same
        // SwiftUI surface.
        let window: NSWindow
        if UIAuditMode.isEnabled || !isScreenLocked {
            // The normal unlocked Island is a standard AppKit panel. SkyLight
            // remains reserved for the protected lock-screen path; using it
            // for every production launch can leave a live process with no
            // visible panel on the active desktop.
            let auditWindow = BoringNotchWindow(
                contentRect: rect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            auditWindow.isOpaque = false
            auditWindow.backgroundColor = .clear
            auditWindow.level = .mainMenu + 3
            auditWindow.collectionBehavior = [
                .fullScreenAuxiliary,
                .stationary,
                // A floating Island may join every Space, but it must also be
                // attached to the Space the person is currently using. A
                // production panel cannot safely combine this with
                // `canJoinAllSpaces`: on macOS it can remain in an inactive
                // Space, leaving a live but invisible Island.
                .moveToActiveSpace,
            ]
            // MacIsland is an accessory surface, not a transient inspector.
            // It must remain visible while another app owns keyboard focus.
            auditWindow.hidesOnDeactivate = false
            if UIAuditMode.isEnabled {
                // Audit needs the inspectable surface to follow Computer Use
                // across Spaces. Keep this test-only behavior out of normal
                // production presentation.
                auditWindow.collectionBehavior.insert(.canJoinAllSpaces)
            }
            auditWindow.hasShadow = false
            auditWindow.isReleasedWhenClosed = false
            window = auditWindow
        } else {
            window = BoringNotchSkyLightWindow(
                contentRect: rect,
                styleMask: styleMask,
                backing: .buffered,
                defer: false
            )
        }
        
        // Enable SkyLight only when screen is locked
        if let skyLightWindow = window as? BoringNotchSkyLightWindow {
            if isScreenLocked {
                skyLightWindow.enableSkyLight()
            } else {
                skyLightWindow.disableSkyLight()
            }
        }

        window.contentView = NSHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
        )

        if UIAuditMode.isEnabled {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            window.orderFrontRegardless()
        }
        NotchSpaceManager.shared.notchSpace.windows.insert(window)

        // Observe when the window's screen changes so we can update drag detectors
        windowScreenDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: window,
            queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.setupDragDetectors()
                }
        }
        return window
    }

    @MainActor
    private func positionWindow(
        _ window: NSWindow,
        on screen: NSScreen,
        with viewModel: BoringViewModel,
        changeAlpha: Bool = false
    ) {
        if changeAlpha {
            window.alphaValue = 0
        }

        // Update the same model that owns this window, then use that exact
        // panel size for both AppKit and the hosted SwiftUI root.
        viewModel.updateMetrics()
        viewModel.updatePanelSize(for: coordinator.currentView)
        let geometry = IslandPanelGeometry(screenFrame: screen.frame, panelSize: viewModel.panelSize)
        let shouldAnimateFrame = IslandMotion.shouldAnimateAppKitStateChanges
            && window.frame.integral != geometry.frame.integral
        if shouldAnimateFrame {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = IslandMotion.appKitStateDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(geometry.frame, display: true)
            }
        } else {
            window.setFrame(geometry.frame, display: true)
        }
        window.alphaValue = 1
    }

    /// Page selection and its first content measurement can arrive in the
    /// same run-loop turn. Coalescing them avoids starting a short transition
    /// to the compact page, then interrupting it with its measured height.
    @MainActor
    private func schedulePanelResize() {
        pendingPanelResize?.cancel()
        let resize = DispatchWorkItem { [weak self] in
            self?.adjustWindowPosition()
        }
        pendingPanelResize = resize
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(16), execute: resize)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEscapeKeyMonitor()
        installUIAuditKeyMonitor()
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: .islandPanelSizeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.schedulePanelResize()
            }
        })
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: .openMirrorRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openMirrorFromUserAction()
        })
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: .closeMirrorRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closeMirrorFromUserAction()
        })
        // Clear session-scoped shelf files before any persisted shelf data is used.
        _ = TemporaryFileStorageService.shared

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.selectedScreenChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
                self?.setupDragDetectors()
            }
        })

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        })

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.automaticallySwitchDisplayChanged, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            Task { @MainActor in
                window.alphaValue = self.coordinator.selectedScreenUUID == self.coordinator.preferredScreenUUID ? 1 : 0
            }
        })

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.showOnAllDisplaysChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.cleanupWindows(shouldInvert: true)
                self.adjustWindowPosition(changeAlpha: true)
                self.setupDragDetectors()
            }
        })

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.expandedDragDetectionChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setupDragDetectors()
            }
        })

        // Use closure-based observers for DistributedNotificationCenter and keep tokens for removal
        screenLockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenLocked(notification)
                }
        }

        screenUnlockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenUnlocked(notification)
            }
        }

        workspaceWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
                self?.setupDragDetectors()
                if AppLifecyclePolicy.shouldResumeCameraAfterWake(
                    isMirrorExpanded: self?.vm.isCameraExpanded == true
                ) {
                    WebcamManager.shared.resumeSessionIfNeeded()
                }
            }
        }

        workspaceSleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            WebcamManager.shared.pauseSessionForSleep()
        }

        KeyboardShortcuts.onKeyDown(for: .toggleSneakPeek) { [weak self] in
            guard let self = self else { return }
            guard !self.isScreenLocked else { return }
            if Defaults[.sneakPeekStyles] == .inline {
                let newStatus = !self.coordinator.expandingView.show
                self.coordinator.toggleExpandingView(status: newStatus, type: .music)
            } else {
                self.coordinator.toggleSneakPeek(
                    status: !self.coordinator.sneakPeek.show,
                    type: .music,
                    duration: 3.0
                )
            }
        }

        KeyboardShortcuts.onKeyDown(for: .toggleNotchOpen) { [weak self] in
            Task { [weak self] in
                guard let self = self else { return }
                guard !self.isScreenLocked else { return }

                let mouseLocation = NSEvent.mouseLocation

                var viewModel = self.vm

                if Defaults[.showOnAllDisplays] {
                    for screen in NSScreen.screens {
                        if screen.frame.contains(mouseLocation) {
                            if let uuid = screen.displayUUID, let screenViewModel = self.viewModels[uuid] {
                                viewModel = screenViewModel
                                break
                            }
                        }
                    }
                }

                self.closeNotchTask?.cancel()
                self.closeNotchTask = nil

                switch viewModel.notchState {
                case .closed:
                    await MainActor.run {
                        viewModel.open()
                    }

                    let task = Task { [weak viewModel] in
                        do {
                            try await Task.sleep(for: .seconds(3))
                            await MainActor.run {
                                viewModel?.close()
                            }
                        } catch { }
                    }
                    self.closeNotchTask = task
                case .open:
                    await MainActor.run {
                        viewModel.close()
                    }
                }
            }
        }

        KeyboardShortcuts.onKeyDown(for: .clipboardHistoryPanel) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard !self.isScreenLocked else { return }
                self.coordinator.currentView = .clipboard
                self.vm.open()
            }
        }

        // Audit mode needs one inspectable panel even when the user's
        // multi-display preference or saved display UUID no longer matches the
        // attached display. Keep that deterministic test-only path separate
        // from normal display routing.
        if UIAuditMode.isEnabled {
            let viewModel = self.vm
            let window = createBoringNotchWindow(
                for: NSScreen.main ?? NSScreen.screens.first!, with: viewModel)
            self.window = window
            positionWindow(window, on: NSScreen.main ?? NSScreen.screens.first!, with: viewModel)
        } else if !Defaults[.showOnAllDisplays] {
            let viewModel = self.vm
            let window = createBoringNotchWindow(
                for: NSScreen.main ?? NSScreen.screens.first!, with: viewModel)
            self.window = window
            adjustWindowPosition(changeAlpha: true)
        } else {
            adjustWindowPosition(changeAlpha: true)
        }

        if UIAuditMode.isEnabled {
            applyUIAuditState(uiAuditState)
        }

        setupDragDetectors()

        if coordinator.firstLaunch {
            DispatchQueue.main.async {
                self.showOnboardingWindow()
            }
        } else if MusicManager.shared.isNowPlayingDeprecated
            && Defaults[.mediaController] == .nowPlaying
        {
            DispatchQueue.main.async {
                self.showOnboardingWindow(step: .musicPermission)
            }
        }

        previousScreens = NSScreen.screens
    }

    @MainActor
    private func openMirrorFromUserAction() {
        guard !isScreenLocked else { return }
        coordinator.currentView = .mirror
        if vm.notchState == .closed { vm.open() }

        if !vm.isCameraExpanded && !WebcamManager.shared.isSessionRunning {
            Defaults[.showMirror] = true
            vm.toggleCameraPreview()
        }
    }

    @MainActor
    private func closeMirrorFromUserAction() {
        WebcamManager.shared.stopSession()
        vm.isCameraExpanded = false
    }

    @MainActor
    private func applyUIAuditState(_ state: UIAuditState) {
        UIAuditController.shared.select(state)
        coordinator.firstLaunch = false
        coordinator.alwaysShowTabs = true
        coordinator.stopTimer()
        vm.isCameraExpanded = false
        MusicManager.shared.clearAuditPlaybackOverride()
        MusicManager.shared.isPlaying = false
        MusicManager.shared.isPlayerIdle = true
        // Every audit state must be self-contained. Seed these before choosing
        // a surface so navigation during any audit never falls back to the
        // user's personal Calendar or clipboard history.
        CalendarManager.shared.useAuditEvents(UIAuditFixtures.calendarItems())
        coordinator.useAuditClipboardEntries(UIAuditFixtures.clipboardEntries)
        ShelfStateViewModel.shared.useAuditItems(UIAuditFixtures.shelfItems)

        switch state {
        case .home, .accessibility, .camera, .error:
            coordinator.currentView = .home
            vm.open()
        case .calendarStress:
            coordinator.currentView = .calendar
            vm.open()
        case .calendarHomeStress:
            let tomorrow = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: .now)!
            CalendarManager.shared.useAuditEvents(
                UIAuditFixtures.calendarItems(
                    reference: tomorrow,
                    omittingAllDay: true,
                    longFirstTimedTitle: true
                )
            )
            coordinator.currentView = .home
            vm.open()
        case .snippetsStress:
            coordinator.currentView = .clipboard
            vm.open()
        case .snippetsEmpty:
            coordinator.useAuditClipboardEntries([])
            coordinator.currentView = .clipboard
            vm.open()
        case .shelf:
            coordinator.currentView = .shelf
            vm.open()
        case .timer:
            coordinator.startTimer(seconds: 10)
            vm.close()
        case .media:
            MusicManager.shared.useAuditPlayback(isPlaying: true)
            vm.close()
        case .mediaPlaying, .mediaPaused:
            MusicManager.shared.useAuditPlayback(isPlaying: state == .mediaPlaying)
            coordinator.currentView = .home
            vm.open()
        case .hover, .closed:
            vm.close()
        }

        if state == .camera {
            vm.isCameraExpanded = true
        }

        window?.makeKeyAndOrderFront(nil)
    }

    private func installUIAuditKeyMonitor() {
        guard UIAuditMode.isEnabled else { return }

        uiAuditKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.contains([.command, .option]),
                  let shortcut = event.charactersIgnoringModifiers,
                  let state = UIAuditState(shortcut: shortcut)
            else { return event }

            Task { @MainActor in
                guard let self else { return }
                self.uiAuditState = state
                self.applyUIAuditState(state)
            }
            return nil
        }
    }

    private func installEscapeKeyMonitor() {
        escapeKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in
                self?.closeMirrorForEscapeIfNeeded()
            }
        }
        // Global monitors do not receive events sent to this app. The local
        // companion makes Escape reliable when the island itself is key.
        localEscapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            guard self?.closeMirrorForEscapeIfNeeded() == true else { return event }
            return nil
        }
    }

    @MainActor
    private func closeMirrorForEscapeIfNeeded() -> Bool {
        guard coordinator.currentView == .mirror else { return false }
        vm.close()
        viewModels.values.forEach { $0.close() }
        return true
    }

    func deviceHasNotch() -> Bool {
        if #available(macOS 12.0, *) {
            for screen in NSScreen.screens {
                if screen.safeAreaInsets.top > 0 {
                    return true
                }
            }
        }
        return false
    }

    @objc func screenConfigurationDidChange() {
        let currentScreens = NSScreen.screens

        let screensChanged =
            currentScreens.count != previousScreens?.count
            || Set(currentScreens.compactMap { $0.displayUUID })
                != Set(previousScreens?.compactMap { $0.displayUUID } ?? [])
            || Set(currentScreens.map { $0.frame }) != Set(previousScreens?.map { $0.frame } ?? [])

        previousScreens = currentScreens

        if screensChanged {
            DispatchQueue.main.async { [weak self] in
                // `adjustWindowPosition` removes only detached-display panels.
                // Keeping retained panels avoids a visible close/open jump.
                self?.adjustWindowPosition(changeAlpha: true)
                self?.setupDragDetectors()
            }
        }
    }

    @objc func adjustWindowPosition(changeAlpha: Bool = false) {
        if Defaults[.showOnAllDisplays] {
            let currentScreenUUIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })

            // Remove windows for screens that no longer exist
            for uuid in AppLifecyclePolicy.detachedDisplayIdentifiers(
                existing: Set(windows.keys),
                current: currentScreenUUIDs
            ) {
                if let window = windows[uuid] {
                    window.close()
                    NotchSpaceManager.shared.notchSpace.windows.remove(window)
                    windows.removeValue(forKey: uuid)
                    viewModels.removeValue(forKey: uuid)
                }
            }

            // Create or update windows for all screens
            for screen in NSScreen.screens {
                guard let uuid = screen.displayUUID else { continue }
                
                if windows[uuid] == nil {
                    let viewModel = BoringViewModel(screenUUID: uuid)
                    let window = createBoringNotchWindow(for: screen, with: viewModel)

                    windows[uuid] = window
                    viewModels[uuid] = viewModel
                }

                if let window = windows[uuid], let viewModel = viewModels[uuid] {
                    positionWindow(window, on: screen, with: viewModel, changeAlpha: changeAlpha)

                    if viewModel.notchState == .closed {
                        viewModel.close()
                    }
                }
            }
        } else {
            let selectedScreen: NSScreen

            if let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "") {
                coordinator.selectedScreenUUID = coordinator.preferredScreenUUID ?? ""
                selectedScreen = preferredScreen
            } else if Defaults[.automaticallySwitchDisplay], let mainScreen = NSScreen.main,
                      let mainUUID = mainScreen.displayUUID {
                coordinator.selectedScreenUUID = mainUUID
                selectedScreen = mainScreen
            } else {
                if let window = window {
                    window.alphaValue = 0
                }
                return
            }

            vm.screenUUID = selectedScreen.displayUUID
            vm.updateMetrics()
            if vm.notchState == .closed {
                vm.notchSize = vm.closedNotchSize
            }

            if window == nil {
                window = createBoringNotchWindow(for: selectedScreen, with: vm)
            }

            if let window = window {
                positionWindow(window, on: selectedScreen, with: vm, changeAlpha: changeAlpha)

                if vm.notchState == .closed {
                    vm.close()
                }
            }
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            window?.orderFrontRegardless()
        }
    }

    @objc func showMenu() {
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc func quitAction() {
        NSApplication.shared.terminate(self)
    }

    private func showOnboardingWindow(step: OnboardingStep = .welcome) {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Welcome to MacIsland"
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            window.contentView = NSHostingView(
                rootView: OnboardingView(
                    step: step,
                    onFinish: {
                        window.orderOut(nil)
//                        NSApp.setActivationPolicy(.accessory)
                        window.close()
                        NSApp.deactivate()
                    },
                    onOpenSettings: {
                        window.close()
                        SettingsWindowController.shared.showWindow()
                    }
                ))
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")

            onboardingWindowController = NSWindowController(window: window)
        }

//        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}

extension Notification.Name {
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
    static let expandedDragDetectionChanged = Notification.Name("expandedDragDetectionChanged")
}

enum AppLifecyclePolicy {
    static func detachedDisplayIdentifiers(existing: Set<String>, current: Set<String>) -> Set<String> {
        existing.subtracting(current)
    }

    static func shouldMonitorDragDetection(enabled: Bool, isScreenLocked: Bool) -> Bool {
        enabled && !isScreenLocked
    }

    static func shouldResumeCameraAfterWake(isMirrorExpanded: Bool) -> Bool {
        isMirrorExpanded
    }
}

/// Coalesces high-frequency settings writes into one panel-position update per
/// main-loop turn, which keeps continuous sliders from forcing redundant layout.
@MainActor
final class PanelLayoutInvalidator {
    static let shared = PanelLayoutInvalidator()
    private var scheduled = false

    func request() {
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            NotificationCenter.default.post(name: .notchHeightChanged, object: nil)
        }
    }
}

extension CGRect: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }

    public static func == (lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
