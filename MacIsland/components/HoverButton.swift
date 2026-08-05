//
//  HoverButton.swift
//  boringNotch
//
//  Created by Kraigo on 04.09.2024.
//

import SwiftUI

struct HoverButton: View {
    var icon: String
    var iconColor: Color = .islandPrimaryText
    var scale: Image.Scale = .medium
    /// Optional compact width for dense contextual toolbars.
    var buttonSize: CGFloat? = nil
    var action: () -> Void
    var contentTransition: ContentTransition = .symbolEffect;
    
    @State private var isHovering = false

    var body: some View {
        let size = buttonSize ?? CGFloat(scale == .large ? 40 : IslandStyle.minimumHitTarget)
        
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .contentTransition(contentTransition)
                .font(scale == .large ? .title2 : .body)
                .frame(width: size, height: size)
                .background {
                    Capsule()
                        .fill(isHovering ? Color.islandPressedSurface : .clear)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(IslandPressButtonStyle())
        .onHover { hovering in
            withAnimation(IslandMotion.interaction) {
                isHovering = hovering
            }
        }
    }
}

struct IslandPressButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.38)
            .scaleEffect(configuration.isPressed && IslandMotion.allowsNonessentialMotion ? 0.96 : 1)
            .animation(IslandMotion.interaction, value: configuration.isPressed)
    }
}
