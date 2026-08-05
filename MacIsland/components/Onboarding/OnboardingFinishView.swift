//
//  OnboardingFinishView.swift
//  boringNotch
//
//  Created by Alexander on 2025-06-23.
//


import SwiftUI

struct OnboardingFinishView: View {
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text("MacIsland Is Ready")
                .font(.title2.weight(.semibold))

            Text("Nima Jafari")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Hover over the notch to open it. Change features and shortcuts in Settings.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            VStack(spacing: 12) {
                Button(action: onOpenSettings) {
                    Label("Customize in Settings", systemImage: "gear")
                        .controlSize(.large)
                }
                .controlSize(.large)

                Button("Finish", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    OnboardingFinishView(onFinish: { }, onOpenSettings: { })
}
