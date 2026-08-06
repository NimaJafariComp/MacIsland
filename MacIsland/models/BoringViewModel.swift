//
//  BoringViewModel.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import AppKit
import AVFoundation
import Combine
import Defaults
import os
import SwiftUI

enum CameraPreviewPolicy {
    static func canStart(
        authorizationStatus: AVAuthorizationStatus,
        cameraAvailable: Bool
    ) -> Bool {
        authorizationStatus == .authorized && cameraAvailable
    }
}

/// Semantic open/closed intent and visual presentation are deliberately
/// separate. The phase owns the single, interruptible material morph while
/// `notchState` keeps its existing input, accessibility, and lifecycle role.
enum IslandPresentationPhase: Equatable {
    case compact
    case expanding
    case expanded
    case collapsing
}

class BoringViewModel: NSObject, ObservableObject {
    private static let lifecycleLog = OSLog(subsystem: "com.macisland.app", category: "IslandLifecycle")
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var detector = FullscreenMediaDetector.shared

    @Published var contentType: ContentType = .normal
    @Published private(set) var notchState: NotchState = .closed

    @Published var dragDetectorTargeting: Bool = false
    @Published var generalDropTargeting: Bool = false
    @Published var dropZoneTargeting: Bool = false
    @Published var dropEvent: Bool = false
    @Published var anyDropZoneTargeting: Bool = false
    var cancellables: Set<AnyCancellable> = []
    
    // Stay visible until fullscreen detection has positively identified a
    // fullscreen app. Starting hidden suppresses closed live activities before
    // the detector's first asynchronous publication.
    @Published var hideOnClosed: Bool = false
    @Published private(set) var isScreenLocked: Bool = false

    @Published var edgeAutoOpenActive: Bool = false
    @Published var isHoveringCalendar: Bool = false
    @Published var isBatteryPopoverActive: Bool = false
    /// A confirmation owned by an expanded page must remain interactive even
    /// when its native presentation moves the pointer outside the Island.
    @Published var isModalInteractionActive: Bool = false

    @Published var screenUUID: String?

    @Published var notchSize: CGSize = getClosedNotchSize()
    @Published var closedNotchSize: CGSize = getClosedNotchSize()
    @Published private(set) var closedSurfaceSize: CGSize = getClosedNotchSize()
    @Published private(set) var hoverHitSize: CGSize = getClosedNotchSize()
    @Published var openIslandSize: CGSize = preferredOpenIslandSize
    @Published var panelSize: CGSize = CGSize(width: preferredOpenIslandSize.width, height: preferredOpenIslandSize.height + shadowPadding)
    /// The visible Island shell has its own continuous geometry progress. It
    /// must not derive its dimensions from the discrete page/open state.
    @Published private(set) var islandMorphProgress: CGFloat = 0
    @Published private(set) var presentationPhase: IslandPresentationPhase = .compact
    /// Compact and expanded content share one stable overlay. Opacity is a
    /// presentation concern; neither value is allowed to change shell bounds.
    @Published private(set) var compactContentOpacity: CGFloat = 1
    @Published private(set) var expandedContentOpacity: CGFloat = 0
    @Published private(set) var isExpandedContentMounted = false
    /// The transparent closed hover target must not be inserted or removed in
    /// the middle of a material morph, where it would shift the visible shell.
    @Published private(set) var usesClosedHoverTarget = true
    @Published private var requestedOpenHeights: [NotchViews: CGFloat] = [:]
    private var deferredPanelCollapse: DispatchWorkItem?
    private var deferredPresentationStage: DispatchWorkItem?
    private var presentationGeneration: UInt = 0
    private var panelGeometryGeneration: UInt = 0
    /// The AppKit host remains fixed while the Island is open. SwiftUI owns
    /// per-page surface sizing inside this transparent envelope, which avoids
    /// a second window-frame animation during rapid tab changes.
    private var openSessionPanelEnvelope: CGSize?
    
    let webcamManager = WebcamManager.shared
    @Published var isCameraExpanded: Bool = false
    @Published var isMirrorRingLightActive: Bool = false
    @Published var mirrorRingLightBrightness: Double = 0.96
    @Published var isMirrorSettingsPresented: Bool = false
    @Published var isRequestingAuthorization: Bool = false

    /// A live preview or lit mirror is an intentional, privacy-sensitive
    /// session. Hover dismissal must not hide it behind the user's back.
    var isMirrorSessionPinned: Bool {
        coordinator.currentView == .mirror
            && (isCameraExpanded || isMirrorRingLightActive || isMirrorSettingsPresented)
    }
    
    deinit {
        destroy()
    }

    func destroy() {
        webcamManager.stopSession()
        deferredPanelCollapse?.cancel()
        deferredPresentationStage?.cancel()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    init(screenUUID: String? = nil) {
        super.init()
        
        self.screenUUID = screenUUID
        updateMetrics()

        Publishers.CombineLatest3($dropZoneTargeting, $dragDetectorTargeting, $generalDropTargeting)
            .map { shelf, drag, general in
                shelf || drag || general
            }
            .assign(to: \.anyDropZoneTargeting, on: self)
            .store(in: &cancellables)
        
        setupDetectorObserver()

        Defaults.publisher(.showMirror)
            .map(\.newValue)
            .removeDuplicates()
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.webcamManager.stopSession()
                self?.isCameraExpanded = false
            }
            .store(in: &cancellables)
    }
    
    private func setupDetectorObserver() {
        // Publisher for the user’s fullscreen detection setting
        let enabledPublisher = Defaults
            .publisher(.hideNotchOption)
            .map(\.newValue)
            .map { $0 != .never }
            .removeDuplicates()

        // Publisher for the current screen UUID (non-nil, distinct)
        let screenPublisher = $screenUUID
            .compactMap { $0 }
            .removeDuplicates()

        // Publisher for fullscreen status dictionary
        let fullscreenStatusPublisher = detector.$fullscreenStatus
            .removeDuplicates()

        // Combine all three: screen UUID, fullscreen status, and enabled setting
        Publishers.CombineLatest3(screenPublisher, fullscreenStatusPublisher, enabledPublisher)
            .map { screenUUID, fullscreenStatus, enabled in
                let isFullscreen = fullscreenStatus[screenUUID] ?? false
                return enabled && isFullscreen
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldHide in
                withAnimation(IslandMotion.content) {
                    self?.hideOnClosed = shouldHide
                }
            }
            .store(in: &cancellables)
    }

    // Computed property for effective notch height
    var effectiveClosedNotchHeight: CGFloat {
        let currentScreen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let noNotchAndFullscreen = hideOnClosed && (currentScreen?.safeAreaInsets.top ?? 0 <= 0 || currentScreen == nil)
        return noNotchAndFullscreen ? 0 : closedNotchSize.height
    }

    var chinHeight: CGFloat {
        if !Defaults[.hideTitleBar] {
            return 0
        }

        guard let currentScreen = screenUUID.flatMap({ NSScreen.screen(withUUID: $0) }) else {
            return 0
        }

        if notchState == .open { return 0 }

        let menuBarHeight = currentScreen.frame.maxY - currentScreen.visibleFrame.maxY
        let currentHeight = effectiveClosedNotchHeight

        if currentHeight == 0 { return 0 }

        return max(0, menuBarHeight - currentHeight)
    }

    func toggleCameraPreview() {
        guard !isScreenLocked else { return }
        if isRequestingAuthorization {
            return
        }

        switch webcamManager.authorizationStatus {
        case .authorized:
            if webcamManager.isSessionRunning {
                webcamManager.stopSession()
                isCameraExpanded = false
            } else if CameraPreviewPolicy.canStart(
                authorizationStatus: webcamManager.authorizationStatus,
                cameraAvailable: webcamManager.cameraAvailable
            ) {
                webcamManager.startSession()
                isCameraExpanded = true
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                let alert = NSAlert()
                alert.messageText = "Camera Access Required"
                alert.informativeText = "Please allow camera access in System Settings."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }

                NSApp.setActivationPolicy(.accessory)
                NSApp.deactivate()
            }

        case .notDetermined:
            isRequestingAuthorization = true
            webcamManager.requestAccessAndStart()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.isRequestingAuthorization = false }

        default:
            break
        }
    }
    
    func isMouseHovering(position: NSPoint = NSEvent.mouseLocation) -> Bool {
        if let metrics = notchMetrics(screenUUID: screenUUID) {
            return metrics.containsHoverPoint(position)
        }
        
        return false
    }

    func open() {
        guard !isScreenLocked else { return }
        deferredPanelCollapse?.cancel()
        deferredPanelCollapse = nil
        guard presentationPhase != .expanding, presentationPhase != .expanded else { return }
        if presentationPhase == .compact {
            openSessionPanelEnvelope = nil
        }
        let transitionID = beginPresentationTransition(toward: .expanding)
        let signpostID = OSSignpostID(log: Self.lifecycleLog)
        os_signpost(.begin, log: Self.lifecycleLog, name: "Island Transition", signpostID: signpostID, "%{public}s", "open")
        let currentPanelSize = panelSize
        updateMetrics()
        let targetSize = activeOpenIslandSize(for: coordinator.currentView)
        let targetPanelSize = persistentPanelEnvelope(
            for: coordinator.currentView,
            visibleSize: targetSize
        )
        panelSize = panelEnvelope(from: currentPanelSize, to: targetPanelSize)
        usesClosedHoverTarget = false
        // Mount the destination before the shell starts animating. It remains
        // transparent until the short content stage, but matched media artwork
        // can now resolve its destination geometry from the first frame.
        isExpandedContentMounted = true
        withAnimation(IslandMotion.islandOpenClose) {
            notchSize = targetSize
            islandMorphProgress = 1
            notchState = .open
        }
        withAnimation(IslandMotion.content) {
            compactContentOpacity = 1
            expandedContentOpacity = 0
        }
        NotificationCenter.default.post(name: .islandPanelSizeDidChange, object: self)
        settlePanelEnvelope(
            at: targetPanelSize,
            while: .open,
            transitionID: transitionID,
            expectedPhase: .expanding
        ) { [weak self] in
            guard let self,
                  self.presentationGeneration == transitionID,
                  self.presentationPhase == .expanding
            else { return }
            self.presentationPhase = .expanded
        }
        schedulePresentationStage(
            after: IslandMotion.expandedPresentationDelay,
            transitionID: transitionID,
            expectedPhase: .expanding
        ) { viewModel in
            withAnimation(IslandMotion.content) {
                viewModel.compactContentOpacity = 0
                viewModel.expandedContentOpacity = 1
            }
        }
        DispatchQueue.main.async {
            os_signpost(.end, log: Self.lifecycleLog, name: "Island Transition", signpostID: signpostID)
        }
        
        // Force music information update when notch is opened
        MusicManager.shared.forceUpdate()
    }

    func close() {
        // Do not close while a share picker, native confirmation, or sharing
        // service is active. These presentations can temporarily move focus
        // outside the nonactivating Island panel.
        if SharingStateManager.shared.preventNotchClose || isModalInteractionActive {
            return
        }
        let signpostID = OSSignpostID(log: Self.lifecycleLog)
        let wasOpen = notchState == .open
        let closingView = coordinator.currentView
        let viewAfterClose: NotchViews
        // Now Playing takes precedence over an optional Shelf landing page so
        // hover always returns to Home when there is active media.
        if !ShelfStateViewModel.shared.isEmpty
            && Defaults[.openShelfByDefault]
            && !MusicManager.shared.isPlaying {
            viewAfterClose = .shelf
        } else if coordinator.openLastTabByDefault {
            viewAfterClose = closingView
        } else {
            viewAfterClose = .home
        }
        os_signpost(.begin, log: Self.lifecycleLog, name: "Island Transition", signpostID: signpostID, "%{public}s", "close")
        let currentPanelSize = panelSize
        guard presentationPhase != .compact || notchState == .open else { return }
        let transitionID = beginPresentationTransition(toward: .collapsing)
        updateMetrics()
        let collapsedPanelSize = panelSize
        panelSize = panelEnvelope(from: currentPanelSize, to: collapsedPanelSize)
        usesClosedHoverTarget = false
        withAnimation(IslandMotion.islandOpenClose) {
            notchSize = closedNotchSize
            closedNotchSize = notchSize
            islandMorphProgress = 0
            notchState = .closed
        }
        // The compact media/activity destination is present from frame zero;
        // the expanded layer retreats over it instead of being swapped out.
        withAnimation(IslandMotion.content) {
            compactContentOpacity = 1
            expandedContentOpacity = 0
        }
        if wasOpen {
            NotificationCenter.default.post(name: .islandPanelSizeDidChange, object: self)
            settlePanelEnvelope(
                at: collapsedPanelSize,
                while: .closed,
                transitionID: transitionID,
                expectedPhase: .collapsing
            ) { [weak self] in
                guard let self,
                      self.presentationGeneration == transitionID,
                      self.presentationPhase == .collapsing
                else { return }
                self.presentationPhase = .compact
                self.isExpandedContentMounted = false
                self.usesClosedHoverTarget = true
                self.openSessionPanelEnvelope = nil
                // Do not replace the tab until the user can no longer see
                // the close morph. Replacing it mid-animation looks like the
                // island briefly reopens to Home.
                if self.coordinator.currentView == closingView {
                    self.coordinator.currentView = viewAfterClose
                }
            }
        }
        self.isBatteryPopoverActive = false
        self.coordinator.sneakPeek.show = false
        self.edgeAutoOpenActive = false
        if isCameraExpanded {
            webcamManager.stopSession()
            isCameraExpanded = false
        }
        isMirrorRingLightActive = false
        isMirrorSettingsPresented = false

        DispatchQueue.main.async {
            os_signpost(.end, log: Self.lifecycleLog, name: "Island Transition", signpostID: signpostID)
        }
    }

    func setScreenLocked(_ locked: Bool) {
        guard isScreenLocked != locked else { return }
        isScreenLocked = locked
        guard locked else { return }

        updateMetrics()
        presentationGeneration &+= 1
        deferredPresentationStage?.cancel()
        deferredPresentationStage = nil
        withAnimation(IslandMotion.state) {
            notchSize = closedNotchSize
            islandMorphProgress = 0
            notchState = .closed
        }
        presentationPhase = .compact
        compactContentOpacity = 1
        expandedContentOpacity = 0
        isExpandedContentMounted = false
        usesClosedHoverTarget = true
        openSessionPanelEnvelope = nil
        isBatteryPopoverActive = false
        edgeAutoOpenActive = false
        if isCameraExpanded {
            webcamManager.stopSession()
            isCameraExpanded = false
        }
        isMirrorRingLightActive = false
        isMirrorSettingsPresented = false
    }

    func updateMetrics() {
        guard let metrics = notchMetrics(screenUUID: screenUUID) else { return }
        closedNotchSize = metrics.closedIslandSize
        closedSurfaceSize = metrics.closedSurfaceSize
        hoverHitSize = metrics.hoverHitSize
        openIslandSize = metrics.openIslandSize
        panelSize = metrics.panelSize
    }

    var currentOpenIslandSize: CGSize {
        activeOpenIslandSize(for: coordinator.currentView)
    }

    func updatePanelSize(for view: NotchViews) {
        let activeSize = notchState == .open ? activeOpenIslandSize(for: view) : openIslandSize
        panelSize = CGSize(width: activeSize.width, height: activeSize.height + shadowPadding)
        if notchState == .open {
            notchSize = activeSize
        }
    }

    /// The borderless AppKit panel is only an interaction/hosting envelope.
    /// Keep it large enough for both endpoints while SwiftUI draws the visible
    /// morph, then settle its transparent bounds after the animation.
    private func panelEnvelope(from current: CGSize, to target: CGSize) -> CGSize {
        CGSize(
            width: max(current.width, target.width),
            height: max(current.height, target.height)
        )
    }

    private func settlePanelEnvelope(
        at target: CGSize,
        while expectedState: NotchState,
        transitionID: UInt? = nil,
        expectedPhase: IslandPresentationPhase? = nil,
        delay: TimeInterval = IslandMotion.islandOpenCloseSettleDelay,
        completion: @escaping () -> Void = {}
    ) {
        deferredPanelCollapse?.cancel()
        panelGeometryGeneration &+= 1
        let panelGeneration = panelGeometryGeneration
        let settlement = DispatchWorkItem { [weak self] in
            guard let self,
                  self.notchState == expectedState,
                  self.panelGeometryGeneration == panelGeneration,
                  transitionID.map({ self.presentationGeneration == $0 }) ?? true,
                  expectedPhase.map({ self.presentationPhase == $0 }) ?? true
            else { return }
            self.panelSize = target
            completion()
            NotificationCenter.default.post(name: .islandPanelSizeDidChange, object: self)
        }
        deferredPanelCollapse = settlement
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: settlement
        )
    }

    /// A monotonically increasing token makes stale delayed presentation work
    /// harmless when a hover reverses direction mid-morph.
    private func beginPresentationTransition(toward phase: IslandPresentationPhase) -> UInt {
        presentationGeneration &+= 1
        deferredPresentationStage?.cancel()
        deferredPresentationStage = nil
        presentationPhase = phase
        return presentationGeneration
    }

    private func schedulePresentationStage(
        after delay: TimeInterval,
        transitionID: UInt,
        expectedPhase: IslandPresentationPhase,
        action: @escaping (BoringViewModel) -> Void
    ) {
        let stage = DispatchWorkItem { [weak self] in
            guard let self,
                  self.presentationGeneration == transitionID,
                  self.presentationPhase == expectedPhase
            else { return }
            action(self)
        }
        deferredPresentationStage = stage
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: stage)
    }

    func requestOpenHeight(_ height: CGFloat, for view: NotchViews) {
        let boundedHeight: CGFloat
        switch view {
        case .calendar:
            boundedHeight = min(max(height, IslandExpandedPageSizing.calendarMinimumHeight), IslandExpandedPageSizing.calendarMaximumHeight)
        case .clipboard:
            boundedHeight = min(
                max(height, IslandExpandedPageSizing.snippetsMinimumHeight),
                IslandExpandedPageSizing.snippetsMaximumHeight
            )
        case .notes:
            boundedHeight = min(max(height, IslandExpandedPageSizing.notesMinimumHeight), IslandExpandedPageSizing.notesMaximumHeight)
        case .mirror:
            boundedHeight = min(max(height, IslandExpandedPageSizing.mirrorMinimumHeight), IslandExpandedPageSizing.mirrorMaximumHeight)
        default:
            return
        }

        let previousHeight = requestedOpenHeights[view] ?? defaultOpenHeight(for: view)
        guard abs(previousHeight - boundedHeight) > 0.5 else { return }
        requestedOpenHeights[view] = boundedHeight
        guard notchState == .open, coordinator.currentView == view else { return }

        let targetSize = activeOpenIslandSize(for: view)
        let targetPanelSize = persistentPanelEnvelope(for: view, visibleSize: targetSize)
        panelSize = panelEnvelope(from: panelSize, to: targetPanelSize)
        withAnimation(IslandMotion.islandOpenClose) {
            notchSize = targetSize
        }
        NotificationCenter.default.post(name: .islandPanelSizeDidChange, object: self)
        settlePanelEnvelope(at: targetPanelSize, while: .open)
    }

    /// Populate a content-sized page's target before changing the visible
    /// page. Otherwise SwiftUI first renders its compact fallback and then
    /// reports its measured height, which creates a second panel transition.
    func selectOpenPage(_ view: NotchViews) {
        if view == .clipboard {
            requestedOpenHeights[.clipboard] = IslandExpandedPageSizing.snippetsHeight(
                entryCount: coordinator.clipboardEntries.count
            )
        } else if view == .mirror {
            requestedOpenHeights[.mirror] = IslandExpandedPageSizing.mirrorPreferredHeight
        } else if view == .notes {
            // Notes refreshes in the background, so its cached rows are
            // available before the tab becomes visible. Start at that exact
            // capped height instead of opening short and growing a frame later.
            requestedOpenHeights[.notes] = IslandExpandedPageSizing.notesHeight(
                recentNoteCount: AppleNotesStore.shared.recentNotes.count
            )
        }

        guard notchState == .open else {
            coordinator.currentView = view
            return
        }

        let size = activeOpenIslandSize(for: view)
        let targetPanelSize = persistentPanelEnvelope(for: view, visibleSize: size)
        panelSize = panelEnvelope(from: panelSize, to: targetPanelSize)
        withAnimation(IslandMotion.islandOpenClose) {
            coordinator.currentView = view
            notchSize = size
        }
        NotificationCenter.default.post(name: .islandPanelSizeDidChange, object: self)
        settlePanelEnvelope(at: targetPanelSize, while: .open)
    }

    /// The black surface remains content-sized, but the transparent AppKit
    /// host stays fixed for the whole open session. This prevents every
    /// dynamic page (Calendar, Snippets, Mirror, and Notes) from issuing an
    /// independent window-frame move while its SwiftUI content resizes.
    private func persistentPanelEnvelope(for view: NotchViews, visibleSize: CGSize) -> CGSize {
        if let openSessionPanelEnvelope {
            return openSessionPanelEnvelope
        }

        let visibleHeight = NSScreen.screen(withUUID: screenUUID ?? "")?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height
            ?? IslandExpandedPageSizing.calendarMaximumHeight
        let dynamicPageCap = min(
            IslandExpandedPageSizing.calendarMaximumHeight,
            max(IslandExpandedPageSizing.calendarMinimumHeight, visibleHeight * 0.65)
        )
        let envelope = CGSize(
            width: visibleSize.width,
            height: max(visibleSize.height, dynamicPageCap) + shadowPadding
        )
        openSessionPanelEnvelope = envelope
        return envelope
    }

    private func activeOpenIslandSize(for view: NotchViews) -> CGSize {
        guard view == .calendar || view == .clipboard || view == .mirror || view == .notes else { return openIslandSize }
        let visibleHeight = NSScreen.screen(withUUID: screenUUID ?? "")?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height
            ?? IslandExpandedPageSizing.calendarMaximumHeight
        let requestedHeight = requestedOpenHeights[view] ?? defaultOpenHeight(for: view)
        let maximumHeight: CGFloat
        switch view {
        case .calendar:
            // A long schedule remains scrollable, but the island never consumes
            // more than a little beyond half the active display.
            maximumHeight = min(
                IslandExpandedPageSizing.calendarMaximumHeight,
                max(IslandExpandedPageSizing.calendarMinimumHeight, visibleHeight * 0.65)
            )
        case .clipboard:
            maximumHeight = IslandExpandedPageSizing.snippetsMaximumHeight
        case .notes:
            maximumHeight = IslandExpandedPageSizing.notesMaximumHeight
        case .mirror:
            maximumHeight = min(
                IslandExpandedPageSizing.mirrorMaximumHeight,
                max(IslandExpandedPageSizing.mirrorMinimumHeight, visibleHeight * 0.65)
            )
        default:
            maximumHeight = openIslandSize.height
        }
        return CGSize(
            width: openIslandSize.width,
            height: min(requestedHeight, maximumHeight)
        )
    }

    private func defaultOpenHeight(for view: NotchViews) -> CGFloat {
        switch view {
        case .calendar:
            IslandExpandedPageSizing.calendarMinimumHeight
        case .mirror:
            IslandExpandedPageSizing.mirrorPreferredHeight
        case .notes:
            IslandExpandedPageSizing.notesMinimumHeight
        case .clipboard:
            IslandExpandedPageSizing.snippetsMinimumHeight
        default:
            IslandExpandedPageSizing.compactHeight
        }
    }

    func closeHello() {
        Task { @MainActor in
            withAnimation(IslandMotion.state) {
                coordinator.helloAnimationRunning = false
                close()
            }
        }
    }
}
