//
//  PermissionsRequestView.swift
//  boringNotch
//
//  Created by Alexander on 2025-06-23.
//

import SwiftUI

struct PermissionRequestView: View {
    let icon: Image
    let title: String
    let description: String
    let privacyNote: String?
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            icon
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 40)
                .foregroundStyle(.primary)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 390)

            if let privacyNote = privacyNote {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                    Text(privacyNote)
                        .multilineTextAlignment(.leading)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 410)
            }

            HStack(spacing: 10) {
                Button("Not Now") { onSkip() }
                    .buttonStyle(.bordered)
                Button("Allow Access") { onAllow() }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
}
