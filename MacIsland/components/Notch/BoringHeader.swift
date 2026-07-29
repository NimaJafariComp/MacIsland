//
//  BoringHeader.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct BoringHeader: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @StateObject var tvm = ShelfStateViewModel.shared
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                if (!tvm.isEmpty || coordinator.alwaysShowTabs) && Defaults[.boringShelf] {
                    TabSelectionView()
                } else if vm.notchState == .open {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open {
                    if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show && Defaults[.showOpenNotchHUD] {
                        OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                            .transition(
                                .scale(scale: 0.8)
                                    .combined(with: .opacity)
                                    .animation(IslandMotion.content)
                            )
                    } else {
                        TimerMenu()
                        if Defaults[.showMirror] {
                            Button(action: {
                                vm.toggleCameraPreview()
                            }) {
                                IslandHeaderButton(icon: "web.camera")
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("Toggle camera mirror")
                            .help("Toggle camera mirror")
                        }
                        if Defaults[.settingsIconInNotch] {
                            Button(action: {
                                DispatchQueue.main.async {
                                    SettingsWindowController.shared.showWindow()
                                }
                                
                            }) {
                                IslandHeaderButton(icon: "gear")
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("Open MacIsland Settings")
                            .help("Open MacIsland Settings")
                        }
                        if Defaults[.showBatteryIndicator] {
                            BoringBatteryView(
                                batteryWidth: 30,
                                isCharging: batteryModel.isCharging,
                                isInLowPowerMode: batteryModel.isInLowPowerMode,
                                isPluggedIn: batteryModel.isPluggedIn,
                                levelBattery: batteryModel.levelBattery,
                                maxCapacity: batteryModel.maxCapacity,
                                timeToFullCharge: batteryModel.timeToFullCharge,
                                isForNotification: false
                            )
                        }
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    func isHUDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }
}

private struct TimerMenu: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @Default(.timerPresets) private var timerPresets

    var body: some View {
        Menu {
            Button("Start 1 minute") { coordinator.startTimer(seconds: 60) }
            Button("Start 5 minutes") { coordinator.startTimer(seconds: 5 * 60) }
            Button("Start 15 minutes") { coordinator.startTimer(seconds: 15 * 60) }
            if !timerPresets.isEmpty {
                Divider()
                ForEach(timerPresets) { preset in
                    Button(preset.name) { coordinator.startTimer(seconds: preset.seconds) }
                }
            }
            Button("Start stopwatch") { coordinator.startStopwatch() }

            if coordinator.timerStatus == .running || coordinator.timerStatus == .paused {
                Divider()
                Button(coordinator.timerStatus == .running ? "Pause timer" : "Resume timer") {
                    coordinator.toggleTimerPause()
                }
                Button("Stop timer", role: .destructive) { coordinator.stopTimer() }
            } else if coordinator.timerStatus == .completed {
                Divider()
                Button("Dismiss timer") { coordinator.stopTimer() }
            }
        } label: {
            IslandHeaderButton(icon: timerIcon)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Timer")
        .help("Timer")
    }

    private var timerIcon: String {
        switch coordinator.timerStatus {
        case .running: "timer"
        case .paused: "pause.circle"
        case .completed: "bell.badge"
        case .idle: "timer"
        }
    }
}

private struct IslandHeaderButton: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.86))
            .frame(width: 28, height: 24)
            .background(Color.islandElevatedSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.islandBorder, lineWidth: 1))
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
