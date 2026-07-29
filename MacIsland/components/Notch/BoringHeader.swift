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
        GeometryReader { proxy in
            let bridgeWidth = vm.closedNotchSize.width
            let sideWidth = max(0, (proxy.size.width - bridgeWidth) / 2)

            HStack(spacing: 0) {
                headerTabs
                    .frame(width: sideWidth, alignment: .leading)

                hardwareBridge
                    .frame(width: bridgeWidth, height: headerHeight)

                headerActions
                    .frame(width: sideWidth, alignment: .trailing)
            }
        }
        .frame(height: headerHeight)
        .foregroundColor(Color.islandSecondaryText)
        .opacity(vm.notchState == .closed ? 0 : 1)
        .blur(radius: vm.notchState == .closed ? 8 : 0)
        .animation(IslandMotion.content, value: vm.notchState)
        .environmentObject(vm)
    }

    private var headerHeight: CGFloat {
        max(24, vm.effectiveClosedNotchHeight)
    }

    @ViewBuilder
    private var headerTabs: some View {
        if (!tvm.isEmpty || coordinator.alwaysShowTabs) && Defaults[.boringShelf] {
            TabSelectionView()
        }
    }

    @ViewBuilder
    private var hardwareBridge: some View {
        if vm.notchState == .open,
           NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 {
            NotchShape()
                .fill(Color.islandHardwareSurface)
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        if vm.notchState == .open {
            if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show && Defaults[.showOpenNotchHUD] {
                OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                    .transition(
                        .scale(scale: 0.8)
                            .combined(with: .opacity)
                            .animation(IslandMotion.content)
                    )
            } else {
                HStack(spacing: IslandStyle.headerActionSpacing) {
                    TimerMenu()
                    if Defaults[.settingsIconInNotch] {
                        HeaderSettingsButton()
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
                .font(IslandTypography.title)
            }
        }
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

/// Settings is a direct destination, so it remains a plain button rather than
/// inheriting the disclosure chevron that AppKit adds to a Menu.
private struct HeaderSettingsButton: View {
    var body: some View {
        Button {
            DispatchQueue.main.async {
                SettingsWindowController.shared.showWindow()
            }
        } label: {
            IslandHeaderButton(icon: "gearshape")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open MacIsland Settings")
        .accessibilityHint("Opens MacIsland Settings")
        .help("MacIsland Settings")
    }
}

private struct TimerMenu: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @Default(.timerPresets) private var timerPresets

    var body: some View {
        Menu {
            Button("Start 1 minute") { startCountdown(seconds: 60) }
            Button("Start 5 minutes") { startCountdown(seconds: 5 * 60) }
            Button("Start 15 minutes") { startCountdown(seconds: 15 * 60) }
            if !timerPresets.isEmpty {
                Divider()
                ForEach(timerPresets) { preset in
                    Button(preset.name) { startCountdown(seconds: preset.seconds) }
                }
            }
            Button("Start stopwatch") { startStopwatch() }

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

    private func startCountdown(seconds: TimeInterval) {
        coordinator.startTimer(seconds: seconds)
        vm.close()
    }

    private func startStopwatch() {
        coordinator.startStopwatch()
        vm.close()
    }
}

private struct IslandHeaderButton: View {
    let icon: String
    @State private var isHovering = false

    var body: some View {
        Image(systemName: icon)
            .font(IslandTypography.control)
            .foregroundStyle(Color.islandPrimaryText)
            .frame(width: IslandStyle.minimumHitTarget, height: IslandStyle.controlHeight)
            .background(
                isHovering ? Color.islandPressedSurface : Color.islandModuleSurface,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        isHovering ? Color.islandBorder : Color.islandModuleBorder,
                        lineWidth: IslandStyle.hairlineWidth
                    )
            }
            .contentShape(Capsule())
            .onHover { hovering in
                withAnimation(IslandMotion.interaction) {
                    isHovering = hovering
                }
            }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
