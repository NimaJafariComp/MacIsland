//
//  BoringViewModel.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

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

    @Published var screenUUID: String?

    @Published var notchSize: CGSize = getClosedNotchSize()
    @Published var closedNotchSize: CGSize = getClosedNotchSize()
    @Published private(set) var closedSurfaceSize: CGSize = getClosedNotchSize()
    @Published private(set) var hoverHitSize: CGSize = getClosedNotchSize()
    @Published var openIslandSize: CGSize = preferredOpenIslandSize
    @Published var panelSize: CGSize = CGSize(width: preferredOpenIslandSize.width, height: preferredOpenIslandSize.height + shadowPadding)
    
    let webcamManager = WebcamManager.shared
    @Published var isCameraExpanded: Bool = false
    @Published var isRequestingAuthorization: Bool = false
    
    deinit {
        destroy()
    }

    func destroy() {
        webcamManager.stopSession()
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
        let signpostID = OSSignpostID(log: Self.lifecycleLog)
        os_signpost(.begin, log: Self.lifecycleLog, name: "Island Transition", signpostID: signpostID, "%{public}s", "open")
        updateMetrics()
        withAnimation(IslandMotion.state) {
            notchSize = openIslandSize
            notchState = .open
        }
        DispatchQueue.main.async {
            os_signpost(.end, log: Self.lifecycleLog, name: "Island Transition", signpostID: signpostID)
        }
        
        // Force music information update when notch is opened
        MusicManager.shared.forceUpdate()
    }

    func close() {
        // Do not close while a share picker or sharing service is active
        if SharingStateManager.shared.preventNotchClose {
            return
        }
        let signpostID = OSSignpostID(log: Self.lifecycleLog)
        os_signpost(.begin, log: Self.lifecycleLog, name: "Island Transition", signpostID: signpostID, "%{public}s", "close")
        updateMetrics()
        withAnimation(IslandMotion.state) {
            notchSize = closedNotchSize
            closedNotchSize = notchSize
            notchState = .closed
        }
        self.isBatteryPopoverActive = false
        self.coordinator.sneakPeek.show = false
        self.edgeAutoOpenActive = false
        if isCameraExpanded {
            webcamManager.stopSession()
            isCameraExpanded = false
        }

        // Set the current view to shelf if it contains files and the user enables openShelfByDefault
        // Otherwise, if the user has not enabled openLastShelfByDefault, set the view to home
    if !ShelfStateViewModel.shared.isEmpty && Defaults[.openShelfByDefault] {
            coordinator.currentView = .shelf
        } else if !coordinator.openLastTabByDefault {
            coordinator.currentView = .home
        }
        DispatchQueue.main.async {
            os_signpost(.end, log: Self.lifecycleLog, name: "Island Transition", signpostID: signpostID)
        }
    }

    func setScreenLocked(_ locked: Bool) {
        guard isScreenLocked != locked else { return }
        isScreenLocked = locked
        guard locked else { return }

        updateMetrics()
        withAnimation(IslandMotion.state) {
            notchSize = closedNotchSize
            notchState = .closed
        }
        isBatteryPopoverActive = false
        edgeAutoOpenActive = false
        if isCameraExpanded {
            webcamManager.stopSession()
            isCameraExpanded = false
        }
    }

    func updateMetrics() {
        guard let metrics = notchMetrics(screenUUID: screenUUID) else { return }
        closedNotchSize = metrics.closedIslandSize
        closedSurfaceSize = metrics.closedSurfaceSize
        hoverHitSize = metrics.hoverHitSize
        openIslandSize = metrics.openIslandSize
        panelSize = metrics.panelSize
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
