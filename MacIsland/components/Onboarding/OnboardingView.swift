//
//  OnboardingView.swift
//  boringNotch
//
//  Created by Alexander on 2025-06-23.
//

import SwiftUI
import AVFoundation
import AppKit

enum OnboardingStep {
    case welcome
    case cameraPermission
    case calendarPermission
    case remindersPermission
    case locationPermission
    case notificationsPermission
    case accessibilityPermission
    case connectedAppsPermission
    case musicPermission
    case finished
}

struct OnboardingView: View {
    @State var step: OnboardingStep = .welcome
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeView {
                    withAnimation(IslandMotion.content) {
                        step = .cameraPermission
                    }
                }
                .transition(.opacity)

            case .cameraPermission:
                PermissionRequestView(
                    icon: Image(systemName: "camera.fill"),
                    title: "Enable Camera Access",
                    description: "MacIsland includes a mirror that shows a live camera preview from the notch. Camera access is used only while the mirror is visible.",
                    privacyNote: "Your camera is never used without your consent, and nothing is recorded or stored.",
                    onAllow: {
                        Task {
                            await requestCameraPermission()
                            withAnimation(IslandMotion.content) {
                                step = .calendarPermission
                            }
                        }
                    },
                    onSkip: {
                        withAnimation(IslandMotion.content) {
                            step = .calendarPermission
                        }
                    }
                )
                .transition(.opacity)

            case .calendarPermission:
                PermissionRequestView(
                    icon: Image(systemName: "calendar"),
                    title: "Enable Calendar Access",
                    description: "MacIsland can show upcoming events beside the notch. Calendar access is required to display your schedule.",
                    privacyNote: "Your calendar data is only used to show your events and is never shared.",
                    onAllow: {
                        Task {
                                await requestCalendarPermission()
                                withAnimation(IslandMotion.content) {
                                    step = .remindersPermission
                                }
                        }
                    },
                    onSkip: {
                            withAnimation(IslandMotion.content) {
                                step = .remindersPermission
                            }
                    }
                )
                .transition(.opacity)

                case .remindersPermission:
                    PermissionRequestView(
                        icon: Image(systemName: "checklist"),
                        title: "Enable Reminders Access",
                        description: "MacIsland can show scheduled reminders alongside calendar events. Reminders access is required to display them.",
                        privacyNote: "Your reminders data is only used to show your reminders and is never shared.",
                        onAllow: {
                            Task {
                                await requestRemindersPermission()
                                withAnimation(IslandMotion.content) {
                                step = .locationPermission
                                }
                            }
                        },
                        onSkip: {
                            withAnimation(IslandMotion.content) {
                                step = .locationPermission
                            }
                        }
                    )
                    .transition(.opacity)

            case .locationPermission:
                PermissionRequestView(
                    icon: Image(systemName: "location.fill"),
                    title: "Enable Location Access",
                    description: "MacIsland uses your current location to show local weather automatically. You can choose a city manually at any time.",
                    privacyNote: "Your location is used only to fetch weather for this Mac and is never shared.",
                    onAllow: {
                        Task {
                            await requestLocationPermission()
                            withAnimation(IslandMotion.content) {
                                step = .notificationsPermission
                            }
                        }
                    },
                    onSkip: {
                        withAnimation(IslandMotion.content) {
                            step = .notificationsPermission
                        }
                    }
                )
                .transition(.opacity)

            case .notificationsPermission:
                PermissionRequestView(
                    icon: Image(systemName: "bell.badge.fill"),
                    title: "Enable Notifications",
                    description: "MacIsland can notify you when a timer finishes, even if the island is not visible.",
                    privacyNote: "Notifications are used only for MacIsland features that you turn on.",
                    onAllow: {
                        Task {
                            await requestNotificationPermission()
                            withAnimation(IslandMotion.content) {
                                step = .accessibilityPermission
                            }
                        }
                    },
                    onSkip: {
                        withAnimation(IslandMotion.content) {
                            step = .accessibilityPermission
                        }
                    }
                )
                .transition(.opacity)
                
            case .accessibilityPermission:
                PermissionRequestView(
                    icon: Image(systemName: "hand.raised.fill"),
                    title: "Enable Accessibility Access",
                    description: "Accessibility access lets MacIsland replace volume and brightness indicators with notch HUDs. It is used only to observe those controls.",
                    privacyNote: "Accessibility access is used only to improve media and brightness notifications. No data is collected or shared.",
                    onAllow: {
                        Task {
                            await requestAccessibilityPermission()
                            withAnimation(IslandMotion.content) {
                                step = .connectedAppsPermission
                            }
                        }
                    },
                    onSkip: {
                        withAnimation(IslandMotion.content) {
                            step = .connectedAppsPermission
                        }
                    }
                )
                .transition(.opacity)

            case .connectedAppsPermission:
                PermissionRequestView(
                    icon: Image(systemName: "link.badge.plus"),
                    title: "Connect Notes and Media Apps",
                    description: "MacIsland can save Quick Notes to Notes and control the media provider you choose, including Spotify or Apple Music.",
                    privacyNote: "MacIsland only reads the connected app's version during setup. macOS remembers your decision for this installed, signed app, so allowed features do not ask again.",
                    onAllow: {
                        Task {
                            await requestConnectedAppsPermission()
                            withAnimation(IslandMotion.content) {
                                step = .musicPermission
                            }
                        }
                    },
                    onSkip: {
                        withAnimation(IslandMotion.content) {
                            step = .musicPermission
                        }
                    }
                )
                .transition(.opacity)
                
            case .musicPermission:
                MusicControllerSelectionView(
                    onContinue: {
                        withAnimation(IslandMotion.content) {
                            BoringViewCoordinator.shared.firstLaunch = false
                            step = .finished
                        }
                    }
                )
                .transition(.opacity)

            case .finished:
                OnboardingFinishView(onFinish: onFinish, onOpenSettings: onOpenSettings)
            }
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - Permission Request Logic

    func requestCameraPermission() async {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func requestCalendarPermission() async {
        await CalendarManager.shared.requestCalendarAccess()
    }

    func requestRemindersPermission() async {
        await CalendarManager.shared.requestReminderAccess()
    }

    func requestLocationPermission() async {
        await BoringViewCoordinator.shared.requestWeatherLocationPermission()
    }

    func requestNotificationPermission() async {
        await BoringViewCoordinator.shared.requestTimerNotificationPermission()
    }
    
    func requestAccessibilityPermission() async {
        await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
    }

    /// macOS Automation consent is scoped to the installed app identity and
    /// target app. A read-only version query primes the same consent that
    /// Notes, Spotify, and Music features later use without changing user data.
    func requestConnectedAppsPermission() async {
        let bundleIdentifiers = ["com.apple.Notes", "com.apple.Music", "com.spotify.client"]
        for bundleIdentifier in bundleIdentifiers where NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil {
            _ = try? await AppleScriptHelper.execute(
                "tell application id \"\(bundleIdentifier)\" to get version"
            )
        }
    }
}
