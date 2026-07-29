//
//  sizeMatters.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 05/08/24.
//

import Defaults
import Foundation
import SwiftUI

/// Shared motion contract for every state change owned by the island.
/// Keeping values together prevents hover, gestures, and panels from looking
/// like separate applications stitched into the same surface.
enum IslandMotionPhase: CaseIterable {
    case state
    case interaction
    case content
    case onboarding
}

enum IslandMotion {
    private static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static var allowsNonessentialMotion: Bool {
        allowsNonessentialMotion(reduceMotion: reduceMotion)
    }

    static func allowsNonessentialMotion(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    /// The visual response budget for one state owner. Reduced Motion keeps
    /// state changes perceptible without leaving work in flight.
    static func durationBudget(
        for phase: IslandMotionPhase,
        reduceMotion: Bool
    ) -> TimeInterval {
        if reduceMotion { return 0.01 }

        return switch phase {
        case .state: 0.28
        case .interaction: 0.16
        case .content: 0.20
        case .onboarding: 0.65
        }
    }

    static var state: Animation {
        reduceMotion
            ? .linear(duration: durationBudget(for: .state, reduceMotion: true))
            : .smooth(duration: durationBudget(for: .state, reduceMotion: false))
    }

    static var interaction: Animation {
        reduceMotion
            ? .linear(duration: durationBudget(for: .interaction, reduceMotion: true))
            : .easeOut(duration: durationBudget(for: .interaction, reduceMotion: false))
    }

    static var content: Animation {
        reduceMotion
            ? .linear(duration: durationBudget(for: .content, reduceMotion: true))
            : .smooth(duration: durationBudget(for: .content, reduceMotion: false))
    }

    static var onboarding: Animation {
        reduceMotion
            ? .linear(duration: durationBudget(for: .onboarding, reduceMotion: true))
            : .easeInOut(duration: durationBudget(for: .onboarding, reduceMotion: false))
    }
}

/// Physical-surface measurements shared by island modules. These intentionally
/// stay quiet so the display hardware remains the visual signature.
enum IslandStyle {
    static let hairlineWidth: CGFloat = 0.75
    static let moduleCornerRadius: CGFloat = 18
    static let controlCornerRadius: CGFloat = 12
    static let modulePadding: CGFloat = 12
    static let controlHeight: CGFloat = 30
    /// Header visuals sit inside the fixed 32 pt camera lane. Their containing
    /// buttons still receive the full lane as a hit target.
    static let headerControlHeight: CGFloat = 28
    static let minimumHitTarget: CGFloat = 32
    static let compactControlCornerRadius: CGFloat = 8
    static let compactControlPadding: CGFloat = 8
    static let compactControlSpacing: CGFloat = 8
    static let headerActionSpacing: CGFloat = 8
    static let panelShadowRadius: CGFloat = 8
    /// Applied inside the open silhouette after its content has been laid out.
    /// Every expanded page must reserve it before choosing module heights.
    static let openSurfacePadding: CGFloat = 12
    /// A small overhang makes the rendered bridge meet, rather than cover, the
    /// physical camera housing. Keep this independent of corner radii.
    static let closedWingWidth: CGFloat = 4
    /// The quiet, centered anchor used where macOS reports no camera housing.
    static let syntheticIslandWidth: CGFloat = 160
    /// Extra interaction room is transparent and extends down from the menu
    /// bar. It must never alter the hardware bridge's rendered silhouette.
    static let extendedHoverPadding: CGFloat = 30
    static let closedHoverShadowRadius: CGFloat = 4

    /// Home and Shelf begin at the same shared shell inset. Home must not add
    /// another horizontal gutter or its cards drift inward from the header and
    /// from Shelf's module edges.
    static let homeHorizontalInset: CGFloat = 0
    /// The shared open-surface inset already separates every page from the
    /// physical header and lower silhouette. Home must not add another vertical
    /// gutter or its modules no longer fit the page shared with Shelf.
    static let homeTopInset: CGFloat = 0
    static let homeBottomInset: CGFloat = 0
    static let homeModuleSpacing: CGFloat = 8
    static let homeSectionSpacing: CGFloat = 8
    static let homeWeatherHeight: CGFloat = 28
    static let homeMediaMinimumWidth: CGFloat = 250
    static let homeCalendarWidth: CGFloat = 215
    static let homeCalendarWidthWithCamera: CGFloat = 178
    static let homeCameraSide: CGFloat = 112
    static let homeCameraMinimumSide: CGFloat = 84

    static func expandedPageSize(
        openIslandSize: CGSize,
        headerHeight: CGFloat,
        surfaceHorizontalInset: CGFloat = cornerRadiusInsets.opened.top + openSurfacePadding
    ) -> CGSize {
        CGSize(
            width: max(0, openIslandSize.width - surfaceHorizontalInset * 2),
            height: max(0, openIslandSize.height - max(24, headerHeight) - openSurfacePadding)
        )
    }

    static func homeContentSize(openIslandSize: CGSize, headerHeight: CGFloat) -> CGSize {
        let page = expandedPageSize(
            openIslandSize: openIslandSize,
            headerHeight: headerHeight
        )
        return CGSize(
            width: max(0, page.width - homeHorizontalInset * 2),
            height: max(0, page.height - homeTopInset - homeBottomInset)
        )
    }

    static var panelShadow: Color {
        Color.islandSurfaceShadow
    }
}

/// Shared type roles keep compact island modules readable without making them
/// look like unrelated controls from different applications.
enum IslandTypography {
    static let title = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.subheadline
    static let metadata = Font.caption
    static let control = Font.system(size: 12, weight: .semibold)
    static let numericControl = Font.system(.subheadline, design: .rounded)
        .monospacedDigit()
        .weight(.semibold)
}

/// Fixed-slot Home layout policy. Media gets the remaining width; optional
/// Calendar and Camera are admitted only when their presence cannot crowd its
/// controls or overflow a narrow island.
struct HomeLayoutBudget: Equatable {
    let availableSize: CGSize
    let mediaWidth: CGFloat
    let calendarWidth: CGFloat?
    let cameraSize: CGSize?
    let moduleHeight: CGFloat

    init(
        availableSize: CGSize,
        wantsCalendar: Bool,
        wantsCamera: Bool,
        showsWeather: Bool
    ) {
        self.availableSize = CGSize(
            width: max(0, availableSize.width),
            height: max(0, availableSize.height)
        )

        let weatherReservedHeight = showsWeather
            ? IslandStyle.homeWeatherHeight + IslandStyle.homeSectionSpacing
            : 0
        moduleHeight = max(0, self.availableSize.height - weatherReservedHeight)

        let cameraCanFitHeight = wantsCamera
            && moduleHeight >= IslandStyle.homeCameraMinimumSide
        let cameraWidth = cameraCanFitHeight ? IslandStyle.homeCameraSide : 0
        let spacing = IslandStyle.homeModuleSpacing
        let mediaMinimum = IslandStyle.homeMediaMinimumWidth

        let canFitCalendarAndCamera = wantsCalendar && cameraCanFitHeight
            && self.availableSize.width >= mediaMinimum
                + IslandStyle.homeCalendarWidthWithCamera
                + cameraWidth
                + spacing * 2
        let canFitCalendar = wantsCalendar
            && self.availableSize.width >= mediaMinimum
                + IslandStyle.homeCalendarWidth
                + spacing
        let canFitCamera = cameraCanFitHeight
            && self.availableSize.width >= mediaMinimum
                + cameraWidth
                + spacing

        if canFitCalendarAndCamera {
            calendarWidth = IslandStyle.homeCalendarWidthWithCamera
            cameraSize = CGSize(
                width: cameraWidth,
                height: min(cameraWidth, moduleHeight)
            )
        } else if canFitCalendar {
            calendarWidth = IslandStyle.homeCalendarWidth
            cameraSize = nil
        } else if canFitCamera {
            calendarWidth = nil
            cameraSize = CGSize(
                width: cameraWidth,
                height: min(cameraWidth, moduleHeight)
            )
        } else {
            calendarWidth = nil
            cameraSize = nil
        }

        let secondaryWidth = (calendarWidth ?? 0) + (cameraSize?.width ?? 0)
        let secondaryCount = (calendarWidth == nil ? 0 : 1) + (cameraSize == nil ? 0 : 1)
        mediaWidth = max(0, self.availableSize.width - secondaryWidth - spacing * CGFloat(secondaryCount))
    }

    var occupiedWidth: CGFloat {
        availableSize.width - mediaWidth
    }
}

let downloadSneakSize: CGSize = .init(width: 65, height: 1)
let batterySneakSize: CGSize = .init(width: 160, height: 1)

// Preserve Boring Notch's proven panel envelope.  Individual pages may choose
// their internal layout, but they must never resize or re-anchor the window.
let shadowPadding: CGFloat = 20
let preferredOpenIslandSize = CGSize(width: 640, height: 190)
let cornerRadiusInsets: (opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) = (opened: (top: 19, bottom: 24), closed: (top: 6, bottom: 14))

enum MusicPlayerImageSizes {
    static let cornerRadiusInset: (opened: CGFloat, closed: CGFloat) = (opened: 13.0, closed: 4.0)
    static let size = (opened: CGSize(width: 78, height: 78), closed: CGSize(width: 20, height: 20))
}

/// Single source of truth for physical display measurements and island layout.
/// Screen APIs report points, so every value in this type stays in points.
struct NotchMetricsInput {
    let screenFrame: CGRect
    let visibleFrame: CGRect
    let safeAreaTop: CGFloat
    let auxiliaryTopLeftWidth: CGFloat
    let auxiliaryTopRightWidth: CGFloat

    init(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeftWidth: CGFloat,
        auxiliaryTopRightWidth: CGFloat
    ) {
        self.screenFrame = screenFrame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryTopLeftWidth = auxiliaryTopLeftWidth
        self.auxiliaryTopRightWidth = auxiliaryTopRightWidth
    }

    init(screen: NSScreen) {
        screenFrame = screen.frame
        visibleFrame = screen.visibleFrame
        safeAreaTop = screen.safeAreaInsets.top
        auxiliaryTopLeftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
        auxiliaryTopRightWidth = screen.auxiliaryTopRightArea?.width ?? 0
    }
}

/// The window's frame is independent of the visible island state and selected
/// page.  Keeping this calculation separate from SwiftUI layout prevents an
/// internal page measurement from moving the physical top-edge anchor.
struct IslandPanelGeometry: Equatable {
    let screenFrame: CGRect
    let panelSize: CGSize

    init(screenFrame: CGRect, panelSize: CGSize) {
        self.screenFrame = screenFrame
        self.panelSize = CGSize(
            width: min(max(1, panelSize.width), max(1, screenFrame.width)),
            height: min(max(1, panelSize.height), max(1, screenFrame.height))
        )
    }

    var frame: CGRect {
        CGRect(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
    }
}

/// Closed live activities may add narrow visual wings, but the central bridge
/// must exactly match the measured camera housing. This keeps artwork and
/// indicators out of the protected hardware span and bounds menu-bar usage.
struct ClosedMediaActivityGeometry: Equatable {
    let bridgeWidth: CGFloat
    let wingWidth: CGFloat

    init(physicalBridgeWidth: CGFloat, closedHeight: CGFloat) {
        bridgeWidth = max(0, physicalBridgeWidth)
        wingWidth = max(0, closedHeight - 12)
    }

    var totalWidth: CGFloat {
        bridgeWidth + wingWidth * 2
    }
}

@MainActor
struct NotchMetrics {
    let screenFrame: CGRect
    let hasPhysicalNotch: Bool
    let physicalNotchSize: CGSize
    let closedIslandSize: CGSize
    let openIslandSize: CGSize

    /// A notchless display receives the same island interactions through a
    /// rendered synthetic anchor; no physical camera-exclusion geometry exists.
    var usesSyntheticIsland: Bool {
        !hasPhysicalNotch
    }

    /// Kept separate so a user can enlarge interaction targets without
    /// changing physical geometry or the rendered island silhouette.
    var hoverHitSize: CGSize {
        let padding = Defaults[.extendHoverArea] ? IslandStyle.extendedHoverPadding : 0
        return CGSize(width: min(screenFrame.width, closedSurfaceSize.width + padding * 2),
                      height: closedSurfaceSize.height + padding)
    }

    /// Rendered size of the quiet bridge around the physical housing. The
    /// physical notch remains the authoritative camera exclusion geometry.
    var closedSurfaceSize: CGSize {
        CGSize(
            width: min(screenFrame.width, closedIslandSize.width + IslandStyle.closedWingWidth * 2),
            height: closedIslandSize.height
        )
    }

    /// The interaction target is intentionally larger than the physical bridge
    /// without changing what is painted into the menu bar.
    var hoverHitFrame: CGRect {
        let hit = hoverHitSize
        return CGRect(
            x: screenFrame.midX - hit.width / 2,
            y: screenFrame.maxY - hit.height,
            width: hit.width,
            height: hit.height
        )
    }

    func containsHoverPoint(_ point: CGPoint) -> Bool {
        hoverHitFrame.contains(point)
    }

    var dragTargetSize: CGSize {
        CGSize(width: openIslandSize.width, height: openIslandSize.height)
    }

    var panelSize: CGSize {
        CGSize(width: openIslandSize.width, height: openIslandSize.height + shadowPadding)
    }

    init(screen: NSScreen) {
        self.init(input: NotchMetricsInput(screen: screen))
    }

    init(input: NotchMetricsInput) {
        screenFrame = input.screenFrame
        hasPhysicalNotch = input.safeAreaTop > 0

        let menuBarHeight = max(0, input.screenFrame.maxY - input.visibleFrame.maxY)
        let safeHeight = max(0, input.safeAreaTop)
        let auxiliaryWidth = input.auxiliaryTopLeftWidth + input.auxiliaryTopRightWidth
        let measuredNotchWidth = input.screenFrame.width - auxiliaryWidth
        let physicalWidth = hasPhysicalNotch
            ? (measuredNotchWidth > 0 && measuredNotchWidth < input.screenFrame.width
                ? measuredNotchWidth + 4
                : IslandStyle.syntheticIslandWidth)
            : 0
        let physicalHeight = hasPhysicalNotch ? safeHeight : 0
        physicalNotchSize = CGSize(width: physicalWidth, height: physicalHeight)

        let closedHeight: CGFloat
        if hasPhysicalNotch {
            switch Defaults[.notchHeightMode] {
            case .matchRealNotchSize: closedHeight = safeHeight
            case .matchMenuBar: closedHeight = menuBarHeight
            default: closedHeight = min(max(Defaults[.notchHeight], 15), 45)
            }
        } else {
            switch Defaults[.nonNotchHeightMode] {
            case .matchMenuBar, .matchRealNotchSize:
                // A notchless display has no real notch to match. Treat the
                // legacy mode as the menu-bar-height synthetic island instead
                // of silently using the unrelated custom-height value.
                closedHeight = menuBarHeight
            case .custom:
                closedHeight = min(max(Defaults[.nonNotchHeight], 16), 40)
            }
        }
        closedIslandSize = CGSize(
            width: hasPhysicalNotch ? physicalWidth : IslandStyle.syntheticIslandWidth,
            height: max(0, closedHeight)
        )

        // Keep a safe edge margin on narrow or unusually scaled displays.
        let horizontalLimit = max(1, input.screenFrame.width - 16)
        let verticalLimit = max(1, input.visibleFrame.height - menuBarHeight)
        openIslandSize = CGSize(
            width: min(preferredOpenIslandSize.width, horizontalLimit),
            height: min(preferredOpenIslandSize.height, verticalLimit)
        )
    }
}

@MainActor
func notchMetrics(screenUUID: String? = nil) -> NotchMetrics? {
    let screen = screenUUID.flatMap(NSScreen.screen(withUUID:)) ?? NSScreen.main
    return screen.map(NotchMetrics.init(screen:))
}

@MainActor func getScreenFrame(_ screenUUID: String? = nil) -> CGRect? {
    notchMetrics(screenUUID: screenUUID)?.screenFrame
}

@MainActor func getClosedNotchSize(screenUUID: String? = nil) -> CGSize {
    notchMetrics(screenUUID: screenUUID)?.closedIslandSize
        ?? CGSize(width: IslandStyle.syntheticIslandWidth, height: Defaults[.nonNotchHeight])
}
