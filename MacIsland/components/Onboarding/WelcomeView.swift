//
//  WelcomeView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 2024. 09. 26..
//

import SwiftUI

struct WelcomeView: View {
    var onGetStarted: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.black)
                    .frame(width: 104, height: 64)

                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Welcome to MacIsland")
                    .font(.title2.weight(.semibold))

                Text("by Nima Jafari")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Media, schedule, files, and system controls—built into your MacBook’s notch.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button("Get Started") {
                onGetStarted?()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                Text("Runs locally. Permissions stay under your control.")
            }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    WelcomeView()
}
