//
//  Color+AccentColor.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-24.
//

import SwiftUI
import Defaults

/// Resolves an island theme with the active accessibility contrast preference.
/// Keep the policy value-based so UI behavior remains deterministic in tests.
struct IslandPalette {
    let theme: IslandTheme
    let increaseContrast: Bool

    var usesHighContrast: Bool {
        theme == .contrast || increaseContrast
    }

    var surface: Color {
        switch theme {
        case .midnight: Color(red: 16 / 255, green: 17 / 255, blue: 20 / 255)
        case .graphite: Color(red: 31 / 255, green: 32 / 255, blue: 35 / 255)
        case .frost: Color(red: 39 / 255, green: 43 / 255, blue: 50 / 255)
        case .contrast: .black
        }
    }

    var elevatedSurface: Color {
        .white.opacity(usesHighContrast ? 0.18 : theme == .frost ? 0.14 : theme == .graphite ? 0.10 : 0.07)
    }

    /// A translucent layer for modules that live inside the hardware-black
    /// island. It preserves a continuous shell while allowing contextual
    /// artwork light to remain visible beneath the content.
    var moduleSurfaceOpacity: Double {
        usesHighContrast ? 0.22 : theme == .frost ? 0.13 : theme == .graphite ? 0.09 : 0.065
    }

    var moduleSurface: Color {
        .white.opacity(moduleSurfaceOpacity)
    }

    var moduleBorderOpacity: Double {
        usesHighContrast ? 0.38 : theme == .frost ? 0.14 : 0.075
    }

    var moduleBorder: Color {
        .white.opacity(moduleBorderOpacity)
    }

    var ambientGlowOpacity: Double {
        usesHighContrast ? 0 : theme == .frost ? 0.16 : 0.24
    }

    var border: Color {
        .white.opacity(borderOpacity)
    }

    var borderOpacity: Double {
        usesHighContrast ? 0.32 : theme == .frost ? 0.16 : theme == .graphite ? 0.09 : 0.06
    }

    var primaryText: Color {
        .white.opacity(usesHighContrast ? 1 : 0.92)
    }

    var secondaryText: Color {
        .white.opacity(usesHighContrast ? 0.82 : 0.58)
    }

    var disabledText: Color {
        .white.opacity(usesHighContrast ? 0.64 : 0.38)
    }

    var pressedSurface: Color {
        .white.opacity(usesHighContrast ? 0.30 : 0.14)
    }

    var disabledSurface: Color {
        .white.opacity(usesHighContrast ? 0.20 : 0.07)
    }
}

extension Color {
    /// Shared island tokens. Keep these separate from the macOS accent: the
    /// accent communicates selection, while the palette communicates depth.
    static let islandHardwareSurface = Color.black

    static var islandSurfaceShadow: Color {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            ? .clear
            : .black.opacity(0.42)
    }

    static func islandPalette(
        theme: IslandTheme,
        increaseContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    ) -> IslandPalette {
        IslandPalette(theme: theme, increaseContrast: increaseContrast)
    }

    static var islandSurface: Color {
        islandPalette(theme: Defaults[.islandTheme]).surface
    }

    static var islandElevatedSurface: Color {
        islandPalette(theme: Defaults[.islandTheme]).elevatedSurface
    }

    static var islandModuleSurface: Color {
        islandPalette(theme: Defaults[.islandTheme]).moduleSurface
    }

    static var islandModuleBorder: Color {
        islandPalette(theme: Defaults[.islandTheme]).moduleBorder
    }

    static var islandAmbientGlowOpacity: Double {
        islandPalette(theme: Defaults[.islandTheme]).ambientGlowOpacity
    }

    static var islandBorder: Color {
        islandPalette(theme: Defaults[.islandTheme]).border
    }

    static var islandSecondaryText: Color {
        islandPalette(theme: Defaults[.islandTheme]).secondaryText
    }

    static var islandPrimaryText: Color {
        islandPalette(theme: Defaults[.islandTheme]).primaryText
    }

    static var islandDisabledText: Color {
        islandPalette(theme: Defaults[.islandTheme]).disabledText
    }

    static var islandPressedSurface: Color {
        islandPalette(theme: Defaults[.islandTheme]).pressedSurface
    }

    static var islandDisabledSurface: Color {
        islandPalette(theme: Defaults[.islandTheme]).disabledSurface
    }

    static var islandFocus: Color {
        islandPalette(theme: Defaults[.islandTheme]).usesHighContrast ? .white : .effectiveAccent
    }

    static var islandTrack: Color {
        islandPalette(theme: Defaults[.islandTheme]).usesHighContrast ? .white.opacity(0.36) : .white.opacity(0.18)
    }

    static var islandScrim: Color {
        .black.opacity(islandPalette(theme: Defaults[.islandTheme]).usesHighContrast ? 0.46 : 0.30)
    }

    /// A nearly transparent fill that preserves the island's hit testing.
    static let islandHitTarget = Color.black.opacity(0.01)

    static var islandPositive: Color {
        islandPalette(theme: Defaults[.islandTheme]).usesHighContrast ? .white : .green
    }

    static var islandCritical: Color {
        islandPalette(theme: Defaults[.islandTheme]).usesHighContrast ? .yellow : .red
    }

    static var islandWarning: Color {
        islandPalette(theme: Defaults[.islandTheme]).usesHighContrast ? .yellow : .orange
    }

    static var effectiveAccent: Color {
        if Defaults[.useCustomAccentColor],
           let colorData = Defaults[.customAccentColorData],
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return Color(nsColor: nsColor)
        }
        return .accentColor
    }
    
    /// Returns a darker version of the accent color suitable for backgrounds
    static var effectiveAccentBackground: Color {
        if Defaults[.useCustomAccentColor],
           let colorData = Defaults[.customAccentColorData],
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return Color(nsColor: nsColor.withSystemEffect(.disabled))
        }
        return Color.effectiveAccent.opacity(0.25)
    }
}

extension NSColor {
    static var effectiveAccent: NSColor {
        if Defaults[.useCustomAccentColor],
           let colorData = Defaults[.customAccentColorData],
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return nsColor
        }
        return NSColor.controlAccentColor
    }
    
    /// Returns a darker version of the accent color as NSColor suitable for backgrounds
    static var effectiveAccentBackground: NSColor {
        if Defaults[.useCustomAccentColor],
           let colorData = Defaults[.customAccentColorData],
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return nsColor.withSystemEffect(.disabled)
        }
        return NSColor.controlAccentColor.withAlphaComponent(0.25)
    }
}
