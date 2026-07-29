//
//  Color+AccentColor.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-24.
//

import SwiftUI
import Defaults

extension Color {
    /// Shared island tokens. Keep these separate from the macOS accent: the
    /// accent communicates selection, while the palette communicates depth.
    static var islandSurface: Color {
        switch Defaults[.islandTheme] {
        case .midnight: Color(red: 16 / 255, green: 17 / 255, blue: 20 / 255)
        case .graphite: Color(red: 31 / 255, green: 32 / 255, blue: 35 / 255)
        case .frost: Color(red: 39 / 255, green: 43 / 255, blue: 50 / 255)
        case .contrast: Color.black
        }
    }

    static var islandElevatedSurface: Color {
        switch Defaults[.islandTheme] {
        case .midnight: Color.white.opacity(0.07)
        case .graphite: Color.white.opacity(0.10)
        case .frost: Color.white.opacity(0.14)
        case .contrast: Color.white.opacity(0.16)
        }
    }

    static var islandBorder: Color {
        switch Defaults[.islandTheme] {
        case .midnight: Color.white.opacity(0.06)
        case .graphite: Color.white.opacity(0.09)
        case .frost: Color.white.opacity(0.16)
        case .contrast: Color.white.opacity(0.24)
        }
    }

    static var islandSecondaryText: Color {
        Defaults[.islandTheme] == .contrast ? .white.opacity(0.78) : .white.opacity(0.58)
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
