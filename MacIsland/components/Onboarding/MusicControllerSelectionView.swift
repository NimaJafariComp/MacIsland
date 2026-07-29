//
//  MusicControllerSelectionView.swift
//  boringNotch
//
//  Created by Alexander on 2025-06-23.
//

import SwiftUI
import Defaults


struct MusicControllerSelectionView: View {
    let onContinue: () -> Void

    @Default(.mediaController) var mediaController
    
    private var availableMediaControllers: [MediaControllerType] {
        if MusicManager.shared.isNowPlayingDeprecated {
            return MediaControllerType.allCases.filter { $0 != .nowPlaying }
        } else {
            return MediaControllerType.allCases
        }
    }
    
    @State private var selectedMediaController: MediaControllerType = Defaults[.mediaController]
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Choose a Music Source")
                    .font(.title2.weight(.semibold))

                Text("You can change this later in Settings.")
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(availableMediaControllers) { controller in
                        ControllerOptionView(
                            controller: controller,
                            isSelected: self.selectedMediaController == controller
                        )
                        .onTapGesture {
                            self.selectedMediaController = controller
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            //Disable scroll if there are 4 or fewer to avoid unnecessary scroll behavior
            .scrollDisabled(availableMediaControllers.count <= 4)

//            Spacer()

            Button("Continue", action: {
                self.mediaController = self.selectedMediaController
                NotificationCenter.default.post(
                    name: Notification.Name.mediaControllerChanged,
                    object: nil
                )
                onContinue()
            })
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
}

struct ControllerOptionView: View {
    let controller: MediaControllerType
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))

            VStack(alignment: .leading, spacing: 4) {
                Text(controller.rawValue)
                    .font(.headline)

                Text(controller.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if controller == .youtubeMusic, let url = URL(string: "https://github.com/pear-devs/pear-desktop") {
                    Link("View on GitHub: pear-devs/pear-desktop", destination: url)
                        .font(.subheadline)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.18))
        )
        .contentShape(Rectangle())
    }
}


extension MediaControllerType {
    var description: String {
        switch self {
        case .nowPlaying:
            return "Works with most media apps, including browsers, to detect what's playing. Note: This may be removed in a future macOS version."
        case .spotify:
            return "Connects directly to the Spotify app."
        case .appleMusic:
            return "Connects directly to the Apple Music app."
        case .youtubeMusic:
            return "Requires a third-party client with API plugin enabled."
        }
    }
}

#Preview {
    MusicControllerSelectionView(onContinue: {})
        .frame(width: 400, height: 600)
}
