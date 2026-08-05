//
//  SettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import AVFoundation
import Defaults
import EventKit
import KeyboardShortcuts
import LaunchAtLogin
import Sparkle
import SwiftUI
import SwiftUIIntrospect

enum SettingsDestination: Hashable, Identifiable {
    case appearance
    case behavior
    case gestures
    case media
    case calendar
    case timer
    case weather
    case hud
    case battery
    case systemStates
    case shelf
    case advanced
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .appearance: "Island"
        case .behavior: "Island & display"
        case .gestures: "Controls & shortcuts"
        case .media: "Media"
        case .calendar: "Calendar"
        case .timer: "Timer"
        case .weather: "Weather"
        case .hud: "HUDs"
        case .battery: "Battery"
        case .systemStates: "System States"
        case .shelf: "Shelf"
        case .advanced: "Advanced"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .appearance: "eye"
        case .behavior: "rectangle.3.group"
        case .gestures: "hand.draw"
        case .media: "play.laptopcomputer"
        case .calendar: "calendar"
        case .timer: "timer"
        case .weather: "cloud.sun"
        case .hud: "dial.medium.fill"
        case .battery: "battery.100.bolt"
        case .systemStates: "dot.radiowaves.left.and.right"
        case .shelf: "books.vertical"
        case .advanced: "gearshape.2"
        case .about: "info.circle"
        }
    }
}

enum SettingsNavigationGroup: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case behavior = "Behavior"
    case gestures = "Gestures"
    case modules = "Modules"
    case advanced = "Advanced"

    var id: String { rawValue }

    var destinations: [SettingsDestination] {
        switch self {
        case .appearance: [.appearance]
        case .behavior: [.behavior]
        case .gestures: [.gestures]
        case .modules: [.media, .calendar, .timer, .weather, .hud, .battery, .systemStates, .shelf]
        case .advanced: [.advanced, .about]
        }
    }
}

enum GestureSettingsPolicy {
    static func trackpadControlsAvailable(hoverOpenEnabled: Bool) -> Bool {
        !hoverOpenEnabled
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsDestination = .appearance
    @State private var settingsAccent = Color.effectiveAccent

    let updaterController: SPUStandardUpdaterController?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(SettingsNavigationGroup.allCases) { group in
                    Section(group.rawValue) {
                        ForEach(group.destinations) { destination in
                            NavigationLink(value: destination) {
                                Label(destination.title, systemImage: destination.symbol)
                            }
                            .accessibilityLabel("\(group.rawValue): \(destination.title)")
                            .accessibilityHint("Shows \(destination.title.lowercased()) settings")
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .tint(settingsAccent)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
            .accessibilityLabel("MacIsland Settings sections")
            .accessibilityHint("Use the arrow keys to move between settings sections")
        } detail: {
            Group {
                switch selectedTab {
                case .appearance:
                    Appearance()
                case .behavior:
                    BehaviorSettings()
                case .gestures:
                    GesturesSettings()
                case .media:
                    Media()
                case .calendar:
                    CalendarSettings()
                case .timer:
                    TimerSettings()
                case .weather:
                    WeatherSettings()
                case .hud:
                    HUD()
                case .battery:
                    Charge()
                case .systemStates:
                    SystemStatesSettings()
                case .shelf:
                    Shelf()
                case .advanced:
                    Advanced()
                case .about:
                    About(updaterController: updaterController)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .tint(settingsAccent)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AccentColorChanged"))) { _ in
            settingsAccent = .effectiveAccent
        }
    }
}

private struct TimerSettings: View {
    @Default(.timerCompletionNotifications) private var timerCompletionNotifications
    @Default(.timerPresets) private var timerPresets
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @State private var presetName = ""
    @State private var presetMinutes = 25

    var body: some View {
        Form {
            Section("Timer") {
                Defaults.Toggle(key: .timerCompletionNotifications) {
                    Text("Notify when countdown finishes")
                }
                Text("MacIsland asks for notification permission when you start a countdown. The in-app alarm continues until you dismiss a finished timer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Custom presets") {
                HStack {
                    TextField("Name", text: $presetName)
                    Stepper("\(presetMinutes) min", value: $presetMinutes, in: 1...1_440)
                    Button("Add") {
                        let preset = TimerPreset(name: presetName, seconds: TimeInterval(presetMinutes * 60))
                        guard !preset.name.isEmpty else { return }
                        timerPresets = timerPresets + [preset]
                        presetName = ""
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if timerPresets.isEmpty {
                    Text("Add named countdowns for your routine.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(timerPresets) { preset in
                        HStack {
                            Text(preset.name)
                            Spacer()
                            Text(preset.durationLabel)
                                .foregroundStyle(.secondary)
                            Button("Delete", role: .destructive) {
                                timerPresets.removeAll { $0.id == preset.id }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .navigationTitle("Timer")
        .onChange(of: timerCompletionNotifications) { _, _ in
            coordinator.updateTimerNotificationPreference()
        }
    }
}

private struct SystemStatesSettings: View {
    @Default(.focusIndicatorEnabled) private var focusIndicatorEnabled
    @Default(.focusIndicatorActive) private var focusIndicatorActive
    @Default(.focusIndicatorName) private var focusIndicatorName
    @Default(.connectivityActivityEnabled) private var connectivityActivityEnabled
    @Default(.showOnLockScreen) private var showOnLockScreen
    @ObservedObject private var coordinator = BoringViewCoordinator.shared

    private var connectivityLabel: String {
        switch coordinator.connectivityState {
        case .unknown: "Not monitoring"
        case .online: "Connected"
        case .offline: "Offline"
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Show Focus state", isOn: $focusIndicatorEnabled)
                TextField("Focus label", text: $focusIndicatorName)
                    .disabled(!focusIndicatorEnabled)
                Toggle("Focus session active", isOn: $focusIndicatorActive)
                    .disabled(!focusIndicatorEnabled)
            } header: {
                Text("Focus")
            } footer: {
                Text("Set this private indicator in MacIsland. macOS does not expose other apps’ Focus state through a public sandboxed API.")
            }

            Section {
                Toggle("Show connectivity changes", isOn: $connectivityActivityEnabled)
                HStack {
                    Text("Current status")
                    Spacer()
                    Text(connectivityLabel)
                        .foregroundStyle(Color.islandSecondaryText)
                }
            } header: {
                Text("Connectivity")
            } footer: {
                Text("MacIsland monitors only whether an internet route is available. It never reads your network name, address, or traffic.")
            }

            Section("Lock screen") {
                Toggle("Show safe hardware bridge on lock screen", isOn: $showOnLockScreen)
                Text("When enabled, MacIsland shows only its non-interactive hardware bridge. Media, timers, Focus, connectivity, Shelf, and camera content stay hidden until you unlock.")
            }
        }
        .navigationTitle("System States")
    }
}

private struct WeatherSettings: View {
    @Default(.weatherEnabled) private var weatherEnabled
    @Default(.weatherLocationMode) private var weatherLocationMode
    @Default(.weatherLocationQuery) private var weatherLocationQuery
    @Default(.weatherTemperatureUnit) private var weatherTemperatureUnit
    @ObservedObject private var coordinator = BoringViewCoordinator.shared

    var body: some View {
        Form {
            Section("Weather") {
                Defaults.Toggle(key: .weatherEnabled) {
                    Text("Show weather on Home")
                }
                Picker("Location", selection: $weatherLocationMode) {
                    ForEach(WeatherLocationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                    .disabled(!weatherEnabled)
                if weatherLocationMode == .custom {
                    TextField("City", text: $weatherLocationQuery)
                        .disabled(!weatherEnabled)
                        .onSubmit { coordinator.refreshWeather(force: true) }
                } else {
                    Text("Uses this Mac’s current location. Weather.app’s private saved-city list is not available to other apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Temperature", selection: $weatherTemperatureUnit) {
                    ForEach(WeatherTemperatureUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .disabled(!weatherEnabled)
                Button("Refresh weather") { coordinator.refreshWeather(force: true) }
                    .disabled(!weatherEnabled || (weatherLocationMode == .custom && weatherLocationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                switch coordinator.weatherStatus {
                case .idle:
                    Text("Weather is off.")
                case .loading:
                    if let snapshot = coordinator.weatherSnapshot {
                        Text("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    } else {
                        Text("Weather data will appear here.")
                    }
                case .ready:
                    if let snapshot = coordinator.weatherSnapshot {
                        Text("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    }
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Weather")
        .onAppear { coordinator.refreshWeather() }
        .onChange(of: weatherEnabled) { _, _ in coordinator.refreshWeather() }
        .onChange(of: weatherLocationMode) { _, _ in coordinator.refreshWeather(force: true) }
    }
}

struct BehaviorSettings: View {
    @State private var screens: [(uuid: String, name: String)] = NSScreen.screens.compactMap { screen in
        guard let uuid = screen.displayUUID else { return nil }
        return (uuid, screen.localizedName)
    }
    @ObservedObject var coordinator = BoringViewCoordinator.shared

    @Default(.nonNotchHeight) var nonNotchHeight
    @Default(.nonNotchHeightMode) var nonNotchHeightMode
    @Default(.notchHeight) var notchHeight
    @Default(.notchHeightMode) var notchHeightMode
    @Default(.showOnAllDisplays) var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) var automaticallySwitchDisplay
    

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { Defaults[.menubarIcon] },
                    set: { Defaults[.menubarIcon] = $0 }
                )) {
                    Text("Show menu bar icon")
                }
                .tint(.effectiveAccent)
                LaunchAtLogin.Toggle("Launch MacIsland at login")
                    .help("Open MacIsland automatically after you sign in.")
                    .accessibilityHint("Registers or removes MacIsland from your macOS login items.")
                Defaults.Toggle(key: .showOnAllDisplays) {
                    Text("Show on all displays")
                }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(
                        name: Notification.Name.showOnAllDisplaysChanged, object: nil)
                }
                Picker("Preferred display", selection: $coordinator.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(screen.uuid as String?)
                    }
                }
                .onChange(of: NSScreen.screens) {
                    screens = NSScreen.screens.compactMap { screen in
                        guard let uuid = screen.displayUUID else { return nil }
                        return (uuid, screen.localizedName)
                    }
                }
                .disabled(showOnAllDisplays)
                
                Defaults.Toggle(key: .automaticallySwitchDisplay) {
                    Text("Automatically switch displays")
                }
                    .onChange(of: automaticallySwitchDisplay) {
                        NotificationCenter.default.post(
                            name: Notification.Name.automaticallySwitchDisplayChanged, object: nil)
                    }
                    .disabled(showOnAllDisplays)
            } header: {
                Text("System features")
            }

            Section {
                Picker(
                    selection: $notchHeightMode,
                    label:
                        Text("Notch height on notch displays")
                ) {
                    Text("Match real notch height")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Match menu bar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: notchHeightMode) {
                    switch notchHeightMode {
                    case .matchRealNotchSize:
                        notchHeight = 38
                    case .matchMenuBar:
                        notchHeight = 44
                    case .custom:
                        notchHeight = 38
                    }
                    PanelLayoutInvalidator.shared.request()
                }
                if notchHeightMode == .custom {
                    Slider(value: $notchHeight, in: 15...45, step: 1) {
                        Text("Custom notch size - \(notchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: notchHeight) {
                        PanelLayoutInvalidator.shared.request()
                    }
                }
                Picker("Synthetic island height on notchless displays", selection: $nonNotchHeightMode) {
                    Text("Match menubar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: nonNotchHeightMode) {
                    switch nonNotchHeightMode {
                    case .matchMenuBar:
                        nonNotchHeight = 24
                    case .custom:
                        nonNotchHeight = 32
                    case .matchRealNotchSize:
                        // Preserve legacy defaults while metrics maps them to
                        // menu-bar height on notchless displays.
                        nonNotchHeight = 24
                    }
                    PanelLayoutInvalidator.shared.request()
                }
                if nonNotchHeightMode == .custom {
                    Slider(value: $nonNotchHeight, in: 0...40, step: 1) {
                        Text("Custom notch size - \(nonNotchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: nonNotchHeight) {
                        PanelLayoutInvalidator.shared.request()
                    }
                }
            } header: {
                Text("Notch sizing")
            }

        }
        .toolbar {
            Button("Quit app") {
                NSApp.terminate(self)
            }
            .controlSize(.extraLarge)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Behavior")
    }
}

private struct GesturesSettings: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @Default(.gestureSensitivity) private var gestureSensitivity
    @Default(.minimumHoverDuration) private var minimumHoverDuration
    @Default(.enableGestures) private var enableGestures
    @Default(.openNotchOnHover) private var openNotchOnHover

    var body: some View {
        Form {
            Section("Pointer") {
                Defaults.Toggle(key: .openNotchOnHover) {
                    Text("Open notch on hover")
                }
                Defaults.Toggle(key: .enableHaptics) {
                    Text("Enable haptic feedback")
                }
                Toggle("Remember last tab", isOn: $coordinator.openLastTabByDefault)
                if openNotchOnHover {
                    Slider(value: $minimumHoverDuration, in: 0...1, step: 0.1) {
                        HStack {
                            Text("Hover delay")
                            Spacer()
                            Text("\(minimumHoverDuration, specifier: "%.1f")s")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: minimumHoverDuration) { _, _ in
                        PanelLayoutInvalidator.shared.request()
                    }
                }
            }

            Section {
                if GestureSettingsPolicy.trackpadControlsAvailable(hoverOpenEnabled: openNotchOnHover) {
                    Defaults.Toggle(key: .enableGestures) {
                        Text("Enable trackpad gestures")
                    }
                    if enableGestures {
                        Toggle("Change media with horizontal gestures", isOn: .constant(false))
                            .disabled(true)
                        Defaults.Toggle(key: .closeGestureEnabled) {
                            Text("Close gesture")
                        }
                        Slider(value: $gestureSensitivity, in: 100...300, step: 100) {
                            HStack {
                                Text("Gesture sensitivity")
                                Spacer()
                                Text(
                                    gestureSensitivity == 100
                                        ? "High" : gestureSensitivity == 200 ? "Medium" : "Low"
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Turn off hover-open to configure trackpad gestures.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Trackpad")
            } footer: {
                Text("When hover-open is off, swipe down with two fingers on the notch to open it. Drag upward on the island to close it; ordinary scrolling never closes MacIsland.")
            }

            ShortcutSettingsSections()
        }
        .navigationTitle("Gestures")
        .onChange(of: openNotchOnHover) { _, enabled in
            if !enabled {
                enableGestures = true
            }
        }
    }
}

struct Charge: View {
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showBatteryIndicator) {
                    Text("Show battery indicator")
                }
                Defaults.Toggle(key: .showPowerStatusNotifications) {
                    Text("Show power status notifications")
                }
            } header: {
                Text("General")
            }
            Section {
                Defaults.Toggle(key: .showBatteryPercentage) {
                    Text("Show battery percentage")
                }
                Defaults.Toggle(key: .showPowerStatusIcons) {
                    Text("Show power status icons")
                }
            } header: {
                Text("Battery Information")
            }
        }
        .onAppear {
            Task { @MainActor in
                await XPCHelperClient.shared.isAccessibilityAuthorized()
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Battery")
    }
}

//struct Downloads: View {
//    @Default(.selectedDownloadIndicatorStyle) var selectedDownloadIndicatorStyle
//    @Default(.selectedDownloadIconStyle) var selectedDownloadIconStyle
//    var body: some View {
//        Form {
//            warningBadge("We don't support downloads yet", "It will be supported later on.")
//            Section {
//                Defaults.Toggle(key: .enableDownloadListener) {
//                    Text("Show download progress")
//                }
//                    .disabled(true)
//                Defaults.Toggle(key: .enableSafariDownloads) {
//                    Text("Enable Safari Downloads")
//                }
//                    .disabled(!Defaults[.enableDownloadListener])
//                Picker("Download indicator style", selection: $selectedDownloadIndicatorStyle) {
//                    Text("Progress bar")
//                        .tag(DownloadIndicatorStyle.progress)
//                    Text("Percentage")
//                        .tag(DownloadIndicatorStyle.percentage)
//                }
//                Picker("Download icon style", selection: $selectedDownloadIconStyle) {
//                    Text("Only app icon")
//                        .tag(DownloadIconStyle.onlyAppIcon)
//                    Text("Only download icon")
//                        .tag(DownloadIconStyle.onlyIcon)
//                    Text("Both")
//                        .tag(DownloadIconStyle.iconAndAppIcon)
//                }
//
//            } header: {
//                HStack {
//                    Text("Download indicators")
//                    comingSoonTag()
//                }
//            }
//            Section {
//                List {
//                    ForEach([].indices, id: \.self) { index in
//                        Text("\(index)")
//                    }
//                }
//                .frame(minHeight: 96)
//                .overlay {
//                    if true {
//                        Text("No excluded apps")
//                            .foregroundStyle(Color(.secondaryLabelColor))
//                    }
//                }
//                .actionBar(padding: 0) {
//                    Group {
//                        Button {
//                        } label: {
//                            Image(systemName: "plus")
//                                .frame(width: 25, height: 16, alignment: .center)
//                                .contentShape(Rectangle())
//                                .foregroundStyle(.secondary)
//                        }
//
//                        Divider()
//                        Button {
//                        } label: {
//                            Image(systemName: "minus")
//                                .frame(width: 20, height: 16, alignment: .center)
//                                .contentShape(Rectangle())
//                                .foregroundStyle(.secondary)
//                        }
//                    }
//                }
//            } header: {
//                HStack(spacing: 4) {
//                    Text("Exclude apps")
//                    comingSoonTag()
//                }
//            }
//        }
//        .navigationTitle("Downloads")
//    }
//}

struct HUD: View {
    @EnvironmentObject var vm: BoringViewModel
    @Default(.inlineHUD) var inlineHUD
    @Default(.enableGradient) var enableGradient
    @Default(.optionKeyAction) var optionKeyAction
    @Default(.hudReplacement) var hudReplacement
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject private var helper = XPCHelperClient.shared
    @State private var accessibilityAuthorized = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replace system HUD")
                            .font(.headline)
                        Text("Replaces the standard macOS volume, display brightness, and keyboard brightness HUDs with a custom design.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 40)
                    Defaults.Toggle("", key: .hudReplacement)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.large)
                    .disabled(!accessibilityAuthorized)
                    .accessibilityLabel("Replace system HUD")
                    .accessibilityHint("Replaces the standard macOS volume and brightness indicators")
                }
                
                if !accessibilityAuthorized {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accessibility access is required to replace the system HUD.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button("Request Accessibility") {
                                XPCHelperClient.shared.requestAccessibilityAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.top, 6)
                }

                if helper.connectionState == .unavailable {
                    Label("MacIsland helper is unavailable. Restart MacIsland, then try again.", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            
            Section {
                Picker("Option key behaviour", selection: $optionKeyAction) {
                    ForEach(OptionKeyAction.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                
                Picker("Progress bar style", selection: $enableGradient) {
                    Text("Hierarchical")
                        .tag(false)
                    Text("Gradient")
                        .tag(true)
                }
                Defaults.Toggle(key: .systemEventIndicatorShadow) {
                    Text("Enable glowing effect")
                }
                Defaults.Toggle(key: .systemEventIndicatorUseAccent) {
                    Text("Tint progress bar with accent color")
                }
            } header: {
                Text("General")
            }
            .disabled(!hudReplacement)
            
            Section {
                Defaults.Toggle(key: .showOpenNotchHUD) {
                    Text("Show HUD in open notch")
                }
                Defaults.Toggle(key: .showOpenNotchHUDPercentage) {
                    Text("Show percentage")
                }
                .disabled(!Defaults[.showOpenNotchHUD])
            } header: {
                HStack {
                    Text("Open Notch")
                    customBadge(text: "Beta")
                }
            }
            .disabled(!hudReplacement)
            
            Section {
                Picker("HUD style", selection: $inlineHUD) {
                    Text("Default")
                        .tag(false)
                    Text("Inline")
                        .tag(true)
                }
                .onChange(of: Defaults[.inlineHUD]) {
                    if Defaults[.inlineHUD] {
                        withAnimation(IslandMotion.interaction) {
                            Defaults[.systemEventIndicatorShadow] = false
                            Defaults[.enableGradient] = false
                        }
                    }
                }
                
                Defaults.Toggle(key: .showClosedNotchHUDPercentage) {
                    Text("Show percentage")
                }
            } header: {
                Text("Closed Notch")
            }
            .disabled(!Defaults[.hudReplacement])
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("HUDs")
        .task {
            accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        }
        .onAppear {
            XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()
        }
        .onDisappear {
            XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { notification in
            if let granted = notification.userInfo?["granted"] as? Bool {
                accessibilityAuthorized = granted
            }
        }
    }
}

struct Media: View {
    @Default(.waitInterval) var waitInterval
    @Default(.mediaController) var mediaController
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.hideNotchOption) var hideNotchOption
    @Default(.enableSneakPeek) private var enableSneakPeek
    @Default(.sneakPeekStyles) var sneakPeekStyles

    @Default(.enableLyrics) var enableLyrics

    var body: some View {
        Form {
            Section {
                Picker("Music Source", selection: $mediaController) {
                    ForEach(availableMediaControllers) { controller in
                        Text(controller.rawValue).tag(controller)
                    }
                }
                .onChange(of: mediaController) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.mediaControllerChanged,
                        object: nil
                    )
                }
            } header: {
                Text("Media Source")
            } footer: {
                if MusicManager.shared.isNowPlayingDeprecated {
                    HStack {
                        Text("YouTube Music requires this third-party app to be installed: ")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Link(
                            "https://github.com/pear-devs/pear-desktop",
                            destination: URL(string: "https://github.com/pear-devs/pear-desktop")!
                        )
                        .font(.caption)
                        .foregroundColor(.blue)  // Ensures it's visibly a link
                    }
                } else {
                    Text(
                        "'Now Playing' was the only option on previous versions and works with all media apps."
                    )
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            
            Section {
                Toggle(
                    "Show music live activity",
                    isOn: $coordinator.musicLiveActivityEnabled.animation()
                )
                Toggle("Show sneak peek on playback changes", isOn: $enableSneakPeek)
                Picker("Sneak Peek Style", selection: $sneakPeekStyles) {
                    ForEach(SneakPeekStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                HStack {
                    Stepper(value: $waitInterval, in: 0...10, step: 1) {
                        HStack {
                            Text("Media inactivity timeout")
                            Spacer()
                            Text("\(Defaults[.waitInterval], specifier: "%.0f") seconds")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Picker(
                    selection: $hideNotchOption,
                    label:
                        HStack {
                            Text("Full screen behavior")
                            customBadge(text: "Beta")
                        }
                ) {
                    Text("Hide for all apps").tag(HideNotchOption.always)
                    Text("Hide for media app only").tag(
                        HideNotchOption.nowPlayingOnly)
                    Text("Never hide").tag(HideNotchOption.never)
                }
            } header: {
                Text("Media playback live activity")
            }
            
            Section {
                MusicSlotConfigurationView()
                Defaults.Toggle(key: .enableLyrics) {
                    HStack {
                        Text("Show lyrics below artist name")
                        customBadge(text: "Beta")
                    }
                }
            } header: {
                Text("Media controls")
            }  footer: {
                Text("Customize which controls appear in the music player. Volume expands when active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Media")
    }

    // Only show controller options that are available on this macOS version
    private var availableMediaControllers: [MediaControllerType] {
        if MusicManager.shared.isNowPlayingDeprecated {
            return MediaControllerType.allCases.filter { $0 != .nowPlaying }
        } else {
            return MediaControllerType.allCases
        }
    }
}

struct CalendarSettings: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) var showCalendar: Bool
    @Default(.hideCompletedReminders) var hideCompletedReminders
    @Default(.hideAllDayEvents) var hideAllDayEvents
    @Default(.autoScrollToNextEvent) var autoScrollToNextEvent

    var body: some View {
        Form {
            Defaults.Toggle(key: .showCalendar) {
                Text("Show calendar")
            }
            Defaults.Toggle(key: .hideCompletedReminders) {
                Text("Hide completed reminders")
            }
            Defaults.Toggle(key: .hideAllDayEvents) {
                Text("Hide all-day events")
            }
            Defaults.Toggle(key: .autoScrollToNextEvent) {
                Text("Auto-scroll to next event")
            }
            Defaults.Toggle(key: .showFullEventTitles) {
                Text("Always show full event titles")
            }
            Section(header: Text("Calendars")) {
                if calendarManager.calendarAuthorizationStatus != .fullAccess {
                    Text(calendarPermissionMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    if calendarManager.calendarAuthorizationStatus == .notDetermined {
                        Button("Allow Calendar Access") {
                            Task { await calendarManager.requestCalendarAccess() }
                        }
                    } else {
                        Button("Open Calendar Settings") {
                            openPrivacySettings("Privacy_Calendars")
                        }
                    }
                } else {
                    List {
                        ForEach(calendarManager.eventCalendars, id: \.id) { calendar in
                            Toggle(
                                isOn: Binding(
                                    get: { calendarManager.getCalendarSelected(calendar) },
                                    set: { isSelected in
                                        Task {
                                            await calendarManager.setCalendarSelected(
                                                calendar, isSelected: isSelected)
                                        }
                                    }
                                )
                            ) {
                                Text(calendar.title)
                            }
                            .accentColor(lighterColor(from: calendar.color))
                            .disabled(!showCalendar)
                        }
                    }
                }
            }
            Section(header: Text("Reminders")) {
                if calendarManager.reminderAuthorizationStatus != .fullAccess {
                    Text(reminderPermissionMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    if calendarManager.reminderAuthorizationStatus == .notDetermined {
                        Button("Allow Reminder Access") {
                            Task { await calendarManager.requestReminderAccess() }
                        }
                    } else {
                        Button("Open Reminder Settings") {
                            openPrivacySettings("Privacy_Reminders")
                        }
                    }
                } else {
                    List {
                        ForEach(calendarManager.reminderLists, id: \.id) { calendar in
                            Toggle(
                                isOn: Binding(
                                    get: { calendarManager.getCalendarSelected(calendar) },
                                    set: { isSelected in
                                        Task {
                                            await calendarManager.setCalendarSelected(
                                                calendar, isSelected: isSelected)
                                        }
                                    }
                                )
                            ) {
                                Text(calendar.title)
                            }
                            .accentColor(lighterColor(from: calendar.color))
                            .disabled(!showCalendar)
                        }
                    }
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Calendar")
        .onAppear {
            calendarManager.refreshAuthorizationStatuses()
        }
    }

    private var calendarPermissionMessage: String {
        calendarManager.calendarAuthorizationStatus == .notDetermined
            ? "Allow Calendar access to choose which events MacIsland displays."
            : "Calendar access is denied or restricted. Enable it in System Settings."
    }

    private var reminderPermissionMessage: String {
        calendarManager.reminderAuthorizationStatus == .notDetermined
            ? "Allow Reminders access to choose which lists MacIsland displays."
            : "Reminder access is denied or restricted. Enable it in System Settings."
    }

    private func openPrivacySettings(_ pane: String) {
        guard let settingsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) else { return }
        NSWorkspace.shared.open(settingsURL)
    }
}

func lighterColor(from nsColor: NSColor, amount: CGFloat = 0.14) -> Color {
    let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
    var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
    srgb.getRed(&r, green: &g, blue: &b, alpha: &a)

    func lighten(_ c: CGFloat) -> CGFloat {
        let increased = c + (1.0 - c) * amount
        return min(max(increased, 0), 1)
    }

    let nr = lighten(r)
    let ng = lighten(g)
    let nb = lighten(b)

    return Color(red: Double(nr), green: Double(ng), blue: Double(nb), opacity: Double(a))
}

struct About: View {
    @State private var showBuildNumber: Bool = false
    let updaterController: SPUStandardUpdaterController?
    var body: some View {
        VStack {
            Form {
                Section {
                    HStack {
                        Text("Release name")
                        Spacer()
                        Text(Defaults[.releaseName])
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        withAnimation(IslandMotion.interaction) {
                            showBuildNumber.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Version")
                            Spacer()
                            if showBuildNumber {
                                Text("(\(Bundle.main.buildVersionNumber ?? ""))")
                                    .foregroundStyle(.secondary)
                            }
                            Text(Bundle.main.releaseVersionNumber ?? "unkown")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Version \(Bundle.main.releaseVersionNumber ?? "unknown")")
                    .accessibilityHint("Shows or hides the build number")
                } header: {
                    Text("Version info")
                }

                if let updaterController {
                    UpdaterSettingsView(updater: updaterController.updater)
                } else {
                    Section("Software updates") {
                        Text("Updates are disabled until MacIsland has its own signed release feed.")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 30) {
                    Spacer(minLength: 0)
                    Button {
                        if let url = URL(string: "https://github.com/TheBoredTeam/boring.notch") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image("Github")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18)
                            Text("Boring Notch upstream")
                        }
                        .contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                }
                .buttonStyle(PlainButtonStyle())
            }
            VStack(spacing: 0) {
                Divider()
                Text("MacIsland is GPL-3.0 open source and based on Boring Notch.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
                    .padding(.bottom, 7)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("About")
    }
}

struct Shelf: View {
    
    @Default(.shelfTapToOpen) var shelfTapToOpen: Bool
    @Default(.quickShareProvider) var quickShareProvider
    @Default(.expandedDragDetection) var expandedDragDetection: Bool
    @Default(.clipboardHistoryEnabled) var clipboardHistoryEnabled: Bool
    @Default(.clipboardHistoryLimit) var clipboardHistoryLimit: Int
    @Default(.clipboardExcludedBundleIdentifiers) var clipboardExcludedBundleIdentifiers: String
    @Default(.clipboardCaptureRichText) var clipboardCaptureRichText: Bool
    @StateObject private var quickShareService = QuickShareService.shared

    private var selectedProvider: QuickShareProvider? {
        quickShareService.availableProviders.first(where: { $0.id == quickShareProvider })
    }
    
    init() {
        Task { await QuickShareService.shared.discoverAvailableProviders() }
    }
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .boringShelf) {
                    Text("Enable shelf")
                }
                Defaults.Toggle(key: .openShelfByDefault) {
                    Text("Open shelf by default if items are present")
                }
                Defaults.Toggle(key: .expandedDragDetection) {
                    Text("Expanded drag detection area")
                }
                .onChange(of: expandedDragDetection) {
                    NotificationCenter.default.post(
                        name: Notification.Name.expandedDragDetectionChanged,
                        object: nil
                    )
                }
                Defaults.Toggle(key: .copyOnDrag) {
                    Text("Copy items on drag")
                }
                Defaults.Toggle(key: .autoRemoveShelfItems) {
                    Text("Remove from shelf after dragging")
                }
                Text("Shelf keeps dropped files and links across relaunch using security-scoped access. Temporary representations are removed when MacIsland quits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            } header: {
                HStack {
                    Text("General")
                }
            }
            
            Section {
                Picker("Quick Share Service", selection: $quickShareProvider) {
                    ForEach(quickShareService.availableProviders, id: \.id) { provider in
                        HStack {
                            Group {
                                if let imgData = provider.imageData, let nsImg = NSImage(data: imgData) {
                                    Image(nsImage: nsImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                            .frame(width: 16, height: 16)
                            .foregroundColor(.accentColor)
                            Text(provider.id)
                        }
                        .tag(provider.id)
                    }
                }
                .pickerStyle(.menu)
                
                if let selectedProvider = selectedProvider {
                    HStack {
                        Group {
                            if let imgData = selectedProvider.imageData, let nsImg = NSImage(data: imgData) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .frame(width: 16, height: 16)
                        .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Currently selected: \(selectedProvider.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Files dropped on the shelf will be shared via this service")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                // Providers are always enabled; user can pick default service above.
                
            } header: {
                HStack {
                    Text("Quick Share")
                }
            } footer: {
                Text("Choose which service to use when sharing files from the shelf. Click the shelf button to select files, or drag files onto it to share immediately.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Clipboard history") {
                Defaults.Toggle(key: .clipboardHistoryEnabled) {
                    Text("Capture copied text")
                }
                Stepper("Keep \(clipboardHistoryLimit) snippets", value: $clipboardHistoryLimit, in: 1...100)
                    .disabled(!clipboardHistoryEnabled)
                Defaults.Toggle(key: .clipboardCaptureRichText) {
                    Text("Capture rich text representations")
                }
                .disabled(!clipboardHistoryEnabled)
                TextField("Excluded bundle IDs (comma-separated)", text: $clipboardExcludedBundleIdentifiers)
                    .disabled(!clipboardHistoryEnabled)
                Text("Plain text is stored locally on this Mac. Turn capture off at any time; rich text is ignored by default. Use bundle IDs such as `com.apple.Notes` to exclude apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shelf")
    }
}

//struct Extensions: View {
//    @State private var effectTrigger: Bool = false
//    var body: some View {
//        Form {
//            Section {
//                List {
//                    ForEach(extensionManager.installedExtensions.indices, id: \.self) { index in
//                        let item = extensionManager.installedExtensions[index]
//                        HStack {
//                            AppIcon(for: item.bundleIdentifier)
//                                .resizable()
//                                .frame(width: 24, height: 24)
//                            Text(item.name)
//                            ListItemPopover {
//                                Text("Description")
//                            }
//                            Spacer(minLength: 0)
//                            HStack(spacing: 6) {
//                                Circle()
//                                    .frame(width: 6, height: 6)
//                                    .foregroundColor(
//                                        isExtensionRunning(item.bundleIdentifier)
//                                            ? .green : item.status == .disabled ? .gray : .red
//                                    )
//                                    .conditionalModifier(isExtensionRunning(item.bundleIdentifier))
//                                { view in
//                                    view
//                                        .shadow(color: .green, radius: 3)
//                                }
//                                Text(
//                                    isExtensionRunning(item.bundleIdentifier)
//                                        ? "Running"
//                                        : item.status == .disabled ? "Disabled" : "Stopped"
//                                )
//                                .contentTransition(.numericText())
//                                .foregroundStyle(.secondary)
//                                .font(.footnote)
//                            }
//                            .frame(width: 60, alignment: .leading)
//
//                            Menu(
//                                content: {
//                                    Button("Restart") {
//                                        let ws = NSWorkspace.shared
//
//                                        if let ext = ws.runningApplications.first(where: {
//                                            $0.bundleIdentifier == item.bundleIdentifier
//                                        }) {
//                                            ext.terminate()
//                                        }
//
//                                        if let appURL = ws.urlForApplication(
//                                            withBundleIdentifier: item.bundleIdentifier)
//                                        {
//                                            ws.openApplication(
//                                                at: appURL, configuration: .init(),
//                                                completionHandler: nil)
//                                        }
//                                    }
//                                    .keyboardShortcut("R", modifiers: .command)
//                                    Button("Disable") {
//                                        if let ext = NSWorkspace.shared.runningApplications.first(
//                                            where: { $0.bundleIdentifier == item.bundleIdentifier })
//                                        {
//                                            ext.terminate()
//                                        }
//                                        extensionManager.installedExtensions[index].status =
//                                            .disabled
//                                    }
//                                    .keyboardShortcut("D", modifiers: .command)
//                                    Divider()
//                                    Button("Uninstall", role: .destructive) {
//                                        //
//                                    }
//                                },
//                                label: {
//                                    Image(systemName: "ellipsis.circle")
//                                        .foregroundStyle(.secondary)
//                                }
//                            )
//                            .controlSize(.regular)
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                        .padding(.vertical, 5)
//                    }
//                }
//                .frame(minHeight: 120)
//                .actionBar {
//                    Button {
//                    } label: {
//                        HStack(spacing: 3) {
//                            Image(systemName: "plus")
//                            Text("Add manually")
//                        }
//                        .foregroundStyle(.secondary)
//                    }
//                    .disabled(true)
//                    Spacer()
//                    Button {
//                        withAnimation(.linear(duration: 1)) {
//                            effectTrigger.toggle()
//                        } completion: {
//                            effectTrigger.toggle()
//                        }
//                        extensionManager.checkIfExtensionsAreInstalled()
//                    } label: {
//                        HStack(spacing: 3) {
//                            Image(systemName: "arrow.triangle.2.circlepath")
//                                .rotationEffect(effectTrigger ? .degrees(360) : .zero)
//                        }
//                        .foregroundStyle(.secondary)
//                    }
//                }
//                .controlSize(.small)
//                .buttonStyle(PlainButtonStyle())
//                .overlay {
//                    if extensionManager.installedExtensions.isEmpty {
//                        Text("No extension installed")
//                            .foregroundStyle(Color(.secondaryLabelColor))
//                            .padding(.bottom, 22)
//                    }
//                }
//            } header: {
//                HStack(spacing: 0) {
//                    Text("Installed extensions")
//                    if !extensionManager.installedExtensions.isEmpty {
//                        Text(" – \(extensionManager.installedExtensions.count)")
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            }
//        }
//        .accentColor(.effectiveAccent)
//        .navigationTitle("Extensions")
//        // TipsView()
//        // .padding(.horizontal, 19)
//    }
//}

struct Appearance: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.mirrorShape) var mirrorShape
    @Default(.sliderColor) var sliderColor
    @Default(.useMusicVisualizer) var useMusicVisualizer
    @Default(.customVisualizers) var customVisualizers
    @Default(.selectedVisualizer) var selectedVisualizer
    @Default(.islandTheme) var islandTheme

    @State private var selectedListVisualizer: CustomVisualizer? = nil
    @State private var isPresented: Bool = false
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var speed: CGFloat = 1.0
    var body: some View {
        Form {
            Section {
                Picker("Island theme", selection: $islandTheme) {
                    ForEach(IslandTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                ThemePreview(theme: islandTheme)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            } header: {
                Text("Island appearance")
            } footer: {
                Text(islandTheme.description)
            }

            Section {
                Toggle("Always show tabs", isOn: $coordinator.alwaysShowTabs)
                Defaults.Toggle(key: .settingsIconInNotch) {
                    Text("Show Settings button in island")
                }
            } header: {
                Text("General")
            }

            Section {
                Defaults.Toggle(key: .coloredSpectrogram) {
                    Text("Colored spectrogram")
                }
                Defaults
                    .Toggle("Player tinting", key: .playerColorTinting)
                Defaults.Toggle(key: .lightingEffect) {
                    Text("Enable blur effect behind album art")
                }
                Picker("Slider color", selection: $sliderColor) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { option in
                        Text(option.rawValue)
                    }
                }
            } header: {
                Text("Media")
            }

            Section {
                Toggle(
                    "Use music visualizer spectrogram",
                    isOn: $useMusicVisualizer.animation()
                )
                .disabled(true)
                if !useMusicVisualizer {
                    if customVisualizers.count > 0 {
                        Picker(
                            "Selected animation",
                            selection: $selectedVisualizer
                        ) {
                            ForEach(
                                customVisualizers,
                                id: \.self
                            ) { visualizer in
                                Text(visualizer.name)
                                    .tag(visualizer)
                            }
                        }
                    } else {
                        HStack {
                            Text("Selected animation")
                            Spacer()
                            Text("No custom animation available")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Custom music live activity animation")
                    customBadge(text: "Coming soon")
                }
            }

            Section {
                List {
                    ForEach(customVisualizers, id: \.self) { visualizer in
                        Button {
                            if selectedListVisualizer == visualizer {
                                selectedListVisualizer = nil
                            } else {
                                selectedListVisualizer = visualizer
                            }
                        } label: {
                            HStack {
                                LottieView(
                                    url: visualizer.url, speed: visualizer.speed,
                                    loopMode: .loop
                                )
                                .frame(width: 30, height: 30, alignment: .center)
                                Text(visualizer.name)
                                Spacer(minLength: 0)
                                if selectedVisualizer == visualizer {
                                    Text("selected")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                        .padding(.trailing, 8)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        .background(
                            selectedListVisualizer != nil
                                ? selectedListVisualizer == visualizer
                                    ? Color.effectiveAccent : Color.clear : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .contentShape(Rectangle())
                        .accessibilityLabel(visualizer.name)
                        .accessibilityValue(selectedListVisualizer == visualizer ? "Selected" : "Not selected")
                        .accessibilityHint("Selects this custom visualizer")
                    }
                }
                .safeAreaPadding(
                    EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
                )
                .frame(minHeight: 120)
                .actionBar {
                    HStack(spacing: 5) {
                        Button {
                            name = ""
                            url = ""
                            speed = 1.0
                            isPresented.toggle()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Add custom visualizer")
                        .accessibilityHint("Opens a form for a Lottie animation URL")
                        Divider()
                        Button {
                            if selectedListVisualizer != nil {
                                let visualizer = selectedListVisualizer!
                                selectedListVisualizer = nil
                                customVisualizers.remove(
                                    at: customVisualizers.firstIndex(of: visualizer)!)
                                if visualizer == selectedVisualizer && customVisualizers.count > 0 {
                                    selectedVisualizer = customVisualizers[0]
                                }
                            }
                        } label: {
                            Image(systemName: "minus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                        .disabled(selectedListVisualizer == nil)
                        .accessibilityLabel("Remove selected custom visualizer")
                        .accessibilityHint("Removes the selected animation")
                    }
                }
                .controlSize(.small)
                .buttonStyle(PlainButtonStyle())
                .overlay {
                    if customVisualizers.isEmpty {
                        Text("No custom visualizer")
                            .foregroundStyle(Color(.secondaryLabelColor))
                            .padding(.bottom, 22)
                    }
                }
                .sheet(isPresented: $isPresented) {
                    VStack(alignment: .leading) {
                        Text("Add new visualizer")
                            .font(.largeTitle.bold())
                            .padding(.vertical)
                        TextField("Name", text: $name)
                        TextField("Lottie JSON URL", text: $url)
                        HStack {
                            Text("Speed")
                            Spacer(minLength: 80)
                            Text("\(speed, specifier: "%.1f")s")
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                            Slider(value: $speed, in: 0...2, step: 0.1)
                        }
                        .padding(.vertical)
                        HStack {
                            Button {
                                isPresented.toggle()
                            } label: {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            Button {
                                guard let visualizerURL = URL(string: url) else { return }
                                let visualizer: CustomVisualizer = .init(
                                    UUID: UUID(),
                                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    url: visualizerURL,
                                    speed: speed
                                )

                                if !customVisualizers.contains(visualizer) {
                                    customVisualizers.append(visualizer)
                                }

                                isPresented.toggle()
                            } label: {
                                Text("Add")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || URL(string: url) == nil)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .controlSize(.extraLarge)
                    .padding()
                }
            } header: {
                HStack(spacing: 0) {
                    Text("Custom vizualizers (Lottie)")
                    if !Defaults[.customVisualizers].isEmpty {
                        Text(" – \(Defaults[.customVisualizers].count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Defaults.Toggle(key: .showMirror) {
                    Text("Enable notch mirror")
                }
                    .disabled(!checkVideoInput())
                Picker("Mirror shape", selection: $mirrorShape) {
                    Text("Circle")
                        .tag(MirrorShapeEnum.circle)
                    Text("Square")
                        .tag(MirrorShapeEnum.rectangle)
                }
                Defaults.Toggle(key: .showNotHumanFace) {
                    Text("Show cool face animation while inactive")
                }
            } header: {
                HStack {
                    Text("Additional features")
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Appearance")
    }

    func checkVideoInput() -> Bool {
        if AVCaptureDevice.default(for: .video) != nil {
            return true
        }

        return false
    }
}

private struct ThemePreview: View {
    let theme: IslandTheme

    private var palette: IslandPalette {
        Color.islandPalette(theme: theme)
    }

    private var surface: Color { palette.surface }
    private var border: Color { palette.border }

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.elevatedSurface)
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: "music.note").foregroundStyle(palette.primaryText))
            VStack(alignment: .leading, spacing: 3) {
                Text("MacIsland")
                    .font(IslandTypography.title)
                Text("Focused, native, and calm")
                    .font(IslandTypography.metadata)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Circle().fill(Color.islandFocus).frame(width: 8, height: 8)
        }
        .padding(12)
        .background(surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.rawValue) island theme preview")
    }
}

struct Advanced: View {
    @Default(.useCustomAccentColor) var useCustomAccentColor
    @Default(.customAccentColorData) var customAccentColorData
    @Default(.extendHoverArea) var extendHoverArea
    @Default(.showOnLockScreen) var showOnLockScreen
    @Default(.hideFromScreenRecording) var hideFromScreenRecording
    
    @State private var customAccentColor: Color = .accentColor
    @State private var selectedPresetColor: PresetAccentColor? = nil
    @State private var showingResetConfirmation = false
    
    // macOS accent colors
    enum PresetAccentColor: String, CaseIterable, Identifiable {
        case blue = "Blue"
        case purple = "Purple"
        case pink = "Pink"
        case red = "Red"
        case orange = "Orange"
        case yellow = "Yellow"
        case green = "Green"
        case graphite = "Graphite"
        
        var id: String { self.rawValue }
        
        var color: Color {
            switch self {
            case .blue: return Color(red: 0.0, green: 0.478, blue: 1.0)
            case .purple: return Color(red: 0.686, green: 0.322, blue: 0.871)
            case .pink: return Color(red: 1.0, green: 0.176, blue: 0.333)
            case .red: return Color(red: 1.0, green: 0.271, blue: 0.227)
            case .orange: return Color(red: 1.0, green: 0.584, blue: 0.0)
            case .yellow: return Color(red: 1.0, green: 0.8, blue: 0.0)
            case .green: return Color(red: 0.4, green: 0.824, blue: 0.176)
            case .graphite: return Color(red: 0.557, green: 0.557, blue: 0.576)
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Toggle between system and custom
                    Picker("Accent color", selection: $useCustomAccentColor) {
                        Text("System").tag(false)
                        Text("Custom").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    if !useCustomAccentColor {
                        // System accent info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                AccentCircleButton(
                                    isSelected: true,
                                    color: .accentColor,
                                    isSystemDefault: true,
                                    accessibilityName: "Use macOS system accent color"
                                ) {}
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Using System Accent")
                                        .font(.body)
                                    Text("Your macOS system accent color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        // Custom color options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color Presets")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(PresetAccentColor.allCases) { preset in
                                    AccentCircleButton(
                                        isSelected: selectedPresetColor == preset,
                                        color: preset.color,
                                        accessibilityName: "Use \(preset.rawValue) accent color"
                                    ) {
                                        selectedPresetColor = preset
                                        customAccentColor = preset.color
                                        saveCustomColor(preset.color)
                                        forceUiUpdate()
                                    }
                                }
                                Spacer()
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Custom color picker
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pick a Color")
                                        .font(.body)
                                    Text("Choose any color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                ColorPicker(selection: Binding(
                                    get: { customAccentColor },
                                    set: { newColor in
                                        customAccentColor = newColor
                                        selectedPresetColor = nil
                                        saveCustomColor(newColor)
                                        forceUiUpdate()
                                    }
                                ), supportsOpacity: false) {
                                    ZStack {
                                        Circle()
                                            .fill(customAccentColor)
                                            .frame(width: 32, height: 32)
                                        
                                        if selectedPresetColor == nil {
                                            Circle()
                                                .strokeBorder(.primary.opacity(0.3), lineWidth: 2)
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                                .labelsHidden()
                                .accessibilityLabel("Custom accent color")
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Accent color")
            } footer: {
                Text("Choose between your system accent color or customize it with your own selection.")
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .onAppear {
                initializeAccentColorState()
            }
            
            Section {
                Defaults.Toggle(key: .enableShadow) {
                    Text("Enable window shadow")
                }
                Defaults.Toggle(key: .cornerRadiusScaling) {
                    Text("Corner radius scaling")
                }
            } header: {
                Text("Window Appearance")
            }
            
            Section {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MacIsland icon")
                            .fontWeight(.medium)
                        Text("Installed with the app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } header: {
                Text("App icon")
            }
            
            Section {
                Defaults.Toggle(key: .extendHoverArea) {
                    Text("Extend hover area")
                }
                Defaults.Toggle(key: .hideTitleBar) {
                    Text("Hide title bar")
                }
                Defaults.Toggle(key: .showOnLockScreen) {
                    Text("Show notch on lock screen")
                }
                Defaults.Toggle(key: .hideFromScreenRecording) {
                    Text("Hide from screen recording")
                }
            } header: {
                Text("Window Behavior")
            }

            Section {
                Button("Reset appearance and interaction settings", role: .destructive) {
                    showingResetConfirmation = true
                }
                Text("Resets theme, accent, mirror, sizing, hover, and gesture choices. It keeps permissions, shelf items, media source, shortcuts, and launch-at-login unchanged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Reset")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Advanced")
        .onAppear {
            loadCustomColor()
        }
        .confirmationDialog(
            "Reset appearance and interaction settings?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Settings", role: .destructive) {
                SettingsMigration.resetAppearanceAndInteraction()
                initializeAccentColorState()
                forceUiUpdate()
            }
        } message: {
            Text("Permissions, shelf items, media source, shortcuts, and launch-at-login will not change.")
        }
    }
    
    private func forceUiUpdate() {
        // Force refresh the UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("AccentColorChanged"), object: nil)
        }
    }
    
    private func saveCustomColor(_ color: Color) {
        let nsColor = NSColor(color)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
            Defaults[.customAccentColorData] = colorData
            forceUiUpdate()
        }
    }
    
    private func loadCustomColor() {
        if let colorData = Defaults[.customAccentColorData],
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            customAccentColor = Color(nsColor: nsColor)
            
            // Check if loaded color matches a preset
            selectedPresetColor = nil
            for preset in PresetAccentColor.allCases {
                if colorsAreEqual(Color(nsColor: nsColor), preset.color) {
                    selectedPresetColor = preset
                    break
                }
            }
        }
    }
    
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        let nsColor1 = NSColor(color1).usingColorSpace(.sRGB) ?? NSColor(color1)
        let nsColor2 = NSColor(color2).usingColorSpace(.sRGB) ?? NSColor(color2)
        
        return abs(nsColor1.redComponent - nsColor2.redComponent) < 0.01 &&
               abs(nsColor1.greenComponent - nsColor2.greenComponent) < 0.01 &&
               abs(nsColor1.blueComponent - nsColor2.blueComponent) < 0.01
    }
    
    private func initializeAccentColorState() {
        if !useCustomAccentColor {
            selectedPresetColor = nil // Multicolor is selected when useCustomAccentColor is false
        } else {
            loadCustomColor()
        }
    }
}

// MARK: - Accent Circle Button Component
struct AccentCircleButton: View {
    let isSelected: Bool
    let color: Color
    var isSystemDefault: Bool = false
    var accessibilityName: String = "Accent color"
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Color circle
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                
                // Subtle border
                Circle()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: 32, height: 32)
                
                // Apple-style highlight ring around the middle when selected
                if isSelected {
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.5),
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(isSystemDefault ? "Use your macOS system accent color" : "")
    }
}

private struct ShortcutSettingsSections: View {
    var body: some View {
        Section {
            KeyboardShortcuts.Recorder("Toggle Sneak Peek:", name: .toggleSneakPeek)
        } header: {
            Text("Media shortcut")
        } footer: {
            Text("Sneak Peek shows the media title and artist under the notch for a few seconds.")
        }
        Section {
            KeyboardShortcuts.Recorder("Toggle Notch Open:", name: .toggleNotchOpen)
        } header: {
            Text("MacIsland shortcut")
        }
        Section {
            KeyboardShortcuts.Recorder("Show Snippets:", name: .clipboardHistoryPanel)
        } header: {
            Text("Snippets shortcut")
        } footer: {
            Text("Shows locally stored snippets. Copy still requires an explicit action in MacIsland.")
        }
    }
}

func proFeatureBadge() -> some View {
    Text("Upgrade to Pro")
        .foregroundStyle(Color(red: 0.545, green: 0.196, blue: 0.98))
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4).stroke(
                Color(red: 0.545, green: 0.196, blue: 0.98), lineWidth: 1))
}

func comingSoonTag() -> some View {
    Text("Coming soon")
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func customBadge(text: String) -> some View {
    Text(text)
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func warningBadge(_ text: String, _ description: String) -> some View {
    Section {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading) {
                Text(text)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

#Preview {
    HUD()
}
