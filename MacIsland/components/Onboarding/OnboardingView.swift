//
//  OnboardingView.swift
//  boringNotch
//
//  Created by Alexander on 2025-06-23.
//

import SwiftUI
import AVFoundation

enum OnboardingStep {
    case welcome
    case cameraPermission
    case calendarPermission
    case remindersPermission
    case accessibilityPermission
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
                    withAnimation(.easeInOut(duration: 0.6)) {
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
                            withAnimation(.easeInOut(duration: 0.6)) {
                                step = .calendarPermission
                            }
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.6)) {
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
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    step = .remindersPermission
                                }
                        }
                    },
                    onSkip: {
                            withAnimation(.easeInOut(duration: 0.6)) {
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
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    step = .accessibilityPermission
                                }
                            }
                        },
                        onSkip: {
                            withAnimation(.easeInOut(duration: 0.6)) {
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
                            withAnimation(.easeInOut(duration: 0.6)) {
                                step = .musicPermission
                            }
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            step = .musicPermission
                        }
                    }
                )
                .transition(.opacity)
                
            case .musicPermission:
                MusicControllerSelectionView(
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.6)) {
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
    
    func requestAccessibilityPermission() async {
        await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
    }
}
