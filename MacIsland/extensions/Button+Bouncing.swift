//
//  Button+Bouncing.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 19/08/24.
//
import SwiftUI
import Defaults

struct BouncingButtonStyle: ButtonStyle {
    let vm: BoringViewModel
    @State private var isPressed = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Defaults[.cornerRadiusScaling] ? 10 : MusicPlayerImageSizes.cornerRadiusInset.closed)
                    .fill(isPressed ? Color.islandPressedSurface : Color.islandElevatedSurface)
                    .strokeBorder(Color.islandBorder, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .onChange(of: configuration.isPressed) { _, pressed in
                withAnimation(IslandMotion.interaction) {
                    isPressed = pressed
                }
            }
    }
}

extension Button {
    func bouncingStyle(vm: BoringViewModel) -> some View {
        self.buttonStyle(BouncingButtonStyle(vm: vm))
    }
}
