//
//  TabButton.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-24.
//

import SwiftUI

struct TabButton: View {
    let label: String
    let icon: String
    let selected: Bool
    let width: CGFloat
    let onClick: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onClick) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .frame(
                    width: width,
                    height: IslandStyle.headerControlHeight
                )
                .background {
                    if isHovering && !selected {
                        Capsule().fill(Color.islandElevatedSurface)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(IslandPressButtonStyle())
        .frame(height: IslandStyle.minimumHitTarget)
        .onHover { hovering in
            withAnimation(IslandMotion.interaction) {
                isHovering = hovering
            }
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(label)
    }
}

#Preview {
    TabButton(label: "Home", icon: "tray.fill", selected: true, width: IslandStyle.minimumHitTarget) {
        print("Tapped")
    }
}
