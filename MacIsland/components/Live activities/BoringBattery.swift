import SwiftUI
import Defaults
import IOKit

/// Battery health is distinct from the current charge ceiling reported by
/// IOPowerSources. Read the same design/full-capacity values macOS uses for
/// Battery Health, and leave the value unavailable on desktops or unsupported
/// hardware rather than inventing a percentage.
private struct BatteryHealthSnapshot {
    let maximumCapacityPercent: Int?
    let cycleCount: Int?

    static var current: BatteryHealthSnapshot {
        let matching = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != IO_OBJECT_NULL else {
            return BatteryHealthSnapshot(maximumCapacityPercent: nil, cycleCount: nil)
        }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanagedProperties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let properties = unmanagedProperties?.takeRetainedValue() as? [String: Any]
        else {
            return BatteryHealthSnapshot(maximumCapacityPercent: nil, cycleCount: nil)
        }

        // Newer Macs keep the milliamphour values in `BatteryData`; the root
        // `MaxCapacity` is the current percentage scale (usually 100), not
        // battery health.
        let batteryData = properties["BatteryData"] as? [String: Any]
        let designCapacity = (batteryData?["DesignCapacity"] as? NSNumber)?.doubleValue
        // `NominalChargeCapacity` is macOS's calibrated health capacity.
        // `FullChargeCapacity` is a raw live value and can under-report the
        // Maximum Capacity shown in System Settings.
        let fullChargeCapacity = (
            (batteryData?["NominalChargeCapacity"] as? NSNumber)
                ?? (batteryData?["FullChargeCapacity"] as? NSNumber)
                ?? (batteryData?["AppleRawMaxCapacity"] as? NSNumber)
        )?.doubleValue
        let health: Int?
        if let designCapacity, let fullChargeCapacity, designCapacity > 0 {
            health = Int((fullChargeCapacity / designCapacity * 100).rounded())
        } else {
            health = nil
        }
        let cycles = (properties["CycleCount"] as? NSNumber)?.intValue
        return BatteryHealthSnapshot(maximumCapacityPercent: health, cycleCount: cycles)
    }
}

/// A view that displays the battery status with an icon and charging indicator.
struct BatteryView: View {

    var levelBattery: Float
    var isPluggedIn: Bool
    var isCharging: Bool
    var isInLowPowerMode: Bool
    var batteryWidth: CGFloat = 26
    var isForNotification: Bool

    var icon: String = "battery.0"

    /// Determines the icon to display when charging.
    var iconStatus: String {
        if isCharging {
            return "bolt"
        }
        else if isPluggedIn {
            return "plug"
        }
        else {
            return ""
        }
    }

    /// Determines the color of the battery based on its status.
    var batteryColor: Color {
        if isInLowPowerMode {
            return .islandWarning
        } else if levelBattery <= 20 && !isCharging && !isPluggedIn {
            return .islandCritical
        } else if isCharging || isPluggedIn || levelBattery == 100 {
            return .islandPositive
        } else {
            return .islandPrimaryText
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {

            Image(systemName: icon)
                .resizable()
                .fontWeight(.thin)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(Color.islandDisabledText)
                .frame(
                    width: batteryWidth + 1
                )

            RoundedRectangle(cornerRadius: 2.5)
                .fill(batteryColor)
                .frame(
                    width: CGFloat(((CGFloat(CFloat(levelBattery)) / 100) * (batteryWidth - 6))),
                    height: (batteryWidth - 2.75) - 18
                )
                .padding(.leading, 2)

            if iconStatus != "" && (isForNotification || Defaults[.showPowerStatusIcons]) {
                ZStack {
                    Image(iconStatus)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(Color.islandPrimaryText)
                        .frame(
                            width: 17,
                            height: 17
                        )
                }
                .frame(width: batteryWidth, height: batteryWidth)
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(IslandMotion.interaction, value: configuration.isPressed)
    }
}

/// A view that displays detailed battery information and settings.
struct BatteryMenuView: View {
    
    var isPluggedIn: Bool
    var isCharging: Bool
    var levelBattery: Float
    var maxCapacity: Float
    var timeToFullCharge: Int
    var isInLowPowerMode: Bool
    var onDismiss: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var health = BatteryHealthSnapshot.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack {
                Label("Battery", systemImage: "battery.100percent")
                    .font(IslandTypography.title)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(levelBattery))%")
                    .font(IslandTypography.title)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                batteryRow(
                    title: "Battery Health",
                    value: health.maximumCapacityPercent.map { "\($0)% maximum capacity" } ?? "Unavailable",
                    symbol: "heart.text.square"
                )
                if let cycles = health.cycleCount {
                    batteryRow(title: "Cycle Count", value: "\(cycles)", symbol: "arrow.triangle.2.circlepath")
                }
                batteryRow(
                    title: "Power Mode",
                    value: isInLowPowerMode ? "Low Power Mode" : "Standard",
                    symbol: isInLowPowerMode ? "bolt.fill" : "bolt"
                )
                batteryRow(
                    title: "Power Source",
                    value: isCharging
                        ? (timeToFullCharge > 0 ? "Charging · \(timeToFullCharge) min remaining" : "Charging")
                        : (isPluggedIn ? "Power adapter connected" : "Battery"),
                    symbol: isCharging ? "bolt.fill" : (isPluggedIn ? "powerplug.fill" : "battery.50")
                )

                if isInLowPowerMode {
                    Label("Performance and background activity are limited", systemImage: "speedometer")
                        .font(IslandTypography.metadata)
                        .foregroundStyle(Color.islandSecondaryText)
                }
            }

            Divider().background(Color.islandBorder)

            Button(action: openLowPowerModeSettings) {
                Label(
                    isInLowPowerMode ? "Low Power Mode Settings…" : "Configure Low Power Mode…",
                    systemImage: "bolt.circle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .frame(width: 280)
        .foregroundColor(Color.islandPrimaryText)
        .background(Color.islandModuleSurface)
        .onAppear { health = .current }
    }

    private func batteryRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(Color.islandSecondaryText)
                .frame(width: 16)
            Text(title)
                .font(IslandTypography.body)
            Spacer(minLength: 8)
            Text(value)
                .font(IslandTypography.metadata)
                .foregroundStyle(Color.islandSecondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func openLowPowerModeSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
            openURL(url)
            onDismiss()
        }
    }
}

/// A view that displays the battery status and allows interaction to show detailed information.
struct BoringBatteryView: View {
    
    @State var batteryWidth: CGFloat = 26
    var isCharging: Bool = false
    var isInLowPowerMode: Bool = false
    var isPluggedIn: Bool = false
    var levelBattery: Float = 0
    var maxCapacity: Float = 0
    var timeToFullCharge: Int = 0
    @State var isForNotification: Bool = false
    
    @State private var showPopupMenu: Bool = false
    @State private var isPressed: Bool = false
    @State private var isHoveringButton: Bool = false
    @State private var isHoveringPopover: Bool = false
    @State private var hideTask: Task<Void, Never>? = nil

    @EnvironmentObject var vm: BoringViewModel

    var body: some View {
        Button(action: {
            withAnimation(IslandMotion.interaction) {
                showPopupMenu.toggle()
            }
        }) {
            HStack {
                if Defaults[.showBatteryPercentage] {
                    Text("\(Int32(levelBattery))%")
                        .font(IslandTypography.control)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(Color.islandPrimaryText)
                }
                BatteryView(
                    levelBattery: levelBattery,
                    isPluggedIn: isPluggedIn,
                    isCharging: isCharging,
                    isInLowPowerMode: isInLowPowerMode,
                    batteryWidth: batteryWidth,
                    isForNotification: isForNotification
                )
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .popover(
            isPresented: $showPopupMenu,
            arrowEdge: .bottom) {
            BatteryMenuView(
                isPluggedIn: isPluggedIn,
                isCharging: isCharging,
                levelBattery: levelBattery,
                maxCapacity: maxCapacity,
                timeToFullCharge: timeToFullCharge,
                isInLowPowerMode: isInLowPowerMode,
                onDismiss: { 
                    showPopupMenu = false
                }
            )
            .onHover { hovering in
                isHoveringPopover = hovering
                if hovering {
                    hideTask?.cancel()
                    hideTask = nil
                } else {
                    scheduleHideIfNeeded()
                }
            }
        }
        .onChange(of: showPopupMenu) {
            vm.isBatteryPopoverActive = showPopupMenu
        }
        .onDisappear {
            hideTask?.cancel()
            hideTask = nil
        }
    }

    private func scheduleHideIfNeeded() {
        if isHoveringButton || isHoveringPopover { return }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation(IslandMotion.interaction) { showPopupMenu = false } }
        }
    }
}

#Preview {
    BoringBatteryView(
        batteryWidth: 30,
        isCharging: false,
        isInLowPowerMode: false,
        isPluggedIn: true,
        levelBattery: 80,
        maxCapacity: 100,
        timeToFullCharge: 10,
        isForNotification: false
    ).frame(width: 200, height: 200)
}
