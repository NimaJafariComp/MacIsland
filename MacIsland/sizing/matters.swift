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
enum IslandMotion {
    private static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static var state: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .interactiveSpring(response: 0.32, dampingFraction: 0.84, blendDuration: 0)
    }

    static var interaction: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .interactiveSpring(response: 0.30, dampingFraction: 0.86, blendDuration: 0)
    }

    static var content: Animation {
        reduceMotion ? .linear(duration: 0.01) : .smooth(duration: 0.22)
    }
}

/// Physical-surface measurements shared by island modules. These intentionally
/// stay quiet so the display hardware remains the visual signature.
enum IslandStyle {
    static let moduleCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 12
    static let modulePadding: CGFloat = 12
    static let panelShadowRadius: CGFloat = 8

    static var panelShadow: Color {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            ? .clear
            : .black.opacity(0.42)
    }
}

let downloadSneakSize: CGSize = .init(width: 65, height: 1)
let batterySneakSize: CGSize = .init(width: 160, height: 1)

let shadowPadding: CGFloat = 16
let preferredOpenIslandSize = CGSize(width: 600, height: 176)
let cornerRadiusInsets: (opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) = (opened: (top: 16, bottom: 22), closed: (top: 6, bottom: 14))

enum MusicPlayerImageSizes {
    static let cornerRadiusInset: (opened: CGFloat, closed: CGFloat) = (opened: 13.0, closed: 4.0)
    static let size = (opened: CGSize(width: 78, height: 78), closed: CGSize(width: 20, height: 20))
}

/// Single source of truth for physical display measurements and island layout.
/// Screen APIs report points, so every value in this type stays in points.
@MainActor
struct NotchMetrics {
    let screenFrame: CGRect
    let hasPhysicalNotch: Bool
    let physicalNotchSize: CGSize
    let closedIslandSize: CGSize
    let openIslandSize: CGSize

    /// Kept separate so a user can enlarge interaction targets without
    /// changing physical geometry or the rendered island silhouette.
    var hoverHitSize: CGSize {
        let padding: CGFloat = Defaults[.extendHoverArea] ? 30 : 0
        return CGSize(width: min(screenFrame.width, closedIslandSize.width + padding * 2),
                      height: closedIslandSize.height + padding)
    }

    var dragTargetSize: CGSize {
        CGSize(width: openIslandSize.width, height: openIslandSize.height)
    }

    var panelSize: CGSize {
        CGSize(width: openIslandSize.width, height: openIslandSize.height + shadowPadding)
    }

    init(screen: NSScreen) {
        screenFrame = screen.frame
        hasPhysicalNotch = screen.safeAreaInsets.top > 0

        let menuBarHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let safeHeight = max(0, screen.safeAreaInsets.top)
        let auxiliaryWidth = (screen.auxiliaryTopLeftArea?.width ?? 0)
            + (screen.auxiliaryTopRightArea?.width ?? 0)
        let measuredNotchWidth = screen.frame.width - auxiliaryWidth
        let physicalWidth = measuredNotchWidth > 0 && measuredNotchWidth < screen.frame.width
            ? measuredNotchWidth + 4
            : 160
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
            case .matchMenuBar: closedHeight = menuBarHeight
            default: closedHeight = min(max(Defaults[.nonNotchHeight], 16), 40)
            }
        }
        closedIslandSize = CGSize(
            width: hasPhysicalNotch ? physicalWidth : 160,
            height: max(0, closedHeight)
        )

        // Keep a safe edge margin on narrow or unusually scaled displays.
        let horizontalLimit = max(1, screen.frame.width - 16)
        let verticalLimit = max(1, screen.visibleFrame.height - menuBarHeight)
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
    notchMetrics(screenUUID: screenUUID)?.closedIslandSize ?? CGSize(width: 160, height: Defaults[.nonNotchHeight])
}
