//
//  Constants.swift
//  boringNotch
//
//  Created by Richard Kunkli on 2024. 10. 17..
//

import SwiftUI
import Defaults

private let availableDirectories = FileManager
    .default
    .urls(for: .documentDirectory, in: .userDomainMask)
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let bundleIdentifier = Bundle.main.bundleIdentifier!
let appVersion = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"

let temporaryDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
let spacing: CGFloat = 16

struct CustomVisualizer: Codable, Hashable, Equatable, Defaults.Serializable {
    let UUID: UUID
    var name: String
    var url: URL
    var speed: CGFloat = 1.0
}

enum CalendarSelectionState: Codable, Defaults.Serializable {
    case all
    case selected(Set<String>)
}

enum HideNotchOption: String, Defaults.Serializable {
    case always
    case nowPlayingOnly
    case never
}

/// The visual treatment of the expanded island. Themes deliberately share the
/// same geometry so changing one never changes the interaction target.
enum IslandTheme: String, CaseIterable, Identifiable, Defaults.Serializable {
    case midnight = "Midnight"
    case graphite = "Graphite"
    case frost = "Frost"
    case contrast = "High Contrast"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .midnight: "Deep black with a subtle carbon surface"
        case .graphite: "A softer charcoal treatment for long sessions"
        case .frost: "A cool, translucent graphite treatment"
        case .contrast: "Maximum separation for bright environments"
        }
    }
}

enum WeatherTemperatureUnit: String, CaseIterable, Identifiable, Defaults.Serializable {
    case celsius
    case fahrenheit

    var id: String { rawValue }
    var title: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }
}

enum WeatherLocationMode: String, CaseIterable, Identifiable, Defaults.Serializable {
    case automatic
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: "Automatic (Current Location)"
        case .custom: "Choose a City"
        }
    }
}

struct TimerPreset: Codable, Hashable, Identifiable, Defaults.Serializable {
    let id: UUID
    let name: String
    let seconds: TimeInterval

    init(id: UUID = UUID(), name: String, seconds: TimeInterval) {
        self.id = id
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = String(trimmed.prefix(40))
        self.seconds = min(max(seconds, 60), 24 * 60 * 60)
    }

    var durationLabel: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "1 min"
    }
}

// Define notification names at file scope
extension Notification.Name {
    static let mediaControllerChanged = Notification.Name("mediaControllerChanged")
    static let openMirrorRequested = Notification.Name("openMirrorRequested")
    static let closeMirrorRequested = Notification.Name("closeMirrorRequested")
}

// Media controller types for selection in settings
enum MediaControllerType: String, CaseIterable, Identifiable, Defaults.Serializable {
    case nowPlaying = "Now Playing"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"
    
    var id: String { self.rawValue }
}

// Sneak peek styles for selection in settings
enum SneakPeekStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case standard = "Default"
    case inline = "Inline"
    
    var id: String { self.rawValue }
}

// Action to perform when Option (⌥) is held while pressing media keys
enum OptionKeyAction: String, CaseIterable, Identifiable, Defaults.Serializable {
    case openSettings = "Open System Settings"
    case showHUD = "Show HUD"
    case none = "No Action"

    var id: String { self.rawValue }
}

extension Defaults.Keys {
    static let settingsSchemaVersion = Key<Int>("settingsSchemaVersion", default: 0)
    // MARK: General
    static let menubarIcon = Key<Bool>("menubarIcon", default: true)
    static let showOnAllDisplays = Key<Bool>("showOnAllDisplays", default: false)
    static let automaticallySwitchDisplay = Key<Bool>("automaticallySwitchDisplay", default: true)
    static let releaseName = Key<String>("releaseName", default: "Foundation")
    
    // MARK: Behavior
    static let minimumHoverDuration = Key<TimeInterval>("minimumHoverDuration", default: 0.3)
    static let enableHaptics = Key<Bool>("enableHaptics", default: true)
    static let openNotchOnHover = Key<Bool>("openNotchOnHover", default: true)
    static let extendHoverArea = Key<Bool>("extendHoverArea", default: false)
    static let notchHeightMode = Key<WindowHeightMode>(
        "notchHeightMode",
        default: WindowHeightMode.matchRealNotchSize
    )
    static let nonNotchHeightMode = Key<WindowHeightMode>(
        "nonNotchHeightMode",
        default: WindowHeightMode.matchMenuBar
    )
    static let nonNotchHeight = Key<CGFloat>("nonNotchHeight", default: 32)
    static let notchHeight = Key<CGFloat>("notchHeight", default: 32)
    //static let openLastTabByDefault = Key<Bool>("openLastTabByDefault", default: false)
    static let showOnLockScreen = Key<Bool>("showOnLockScreen", default: false)
    static let hideFromScreenRecording = Key<Bool>("hideFromScreenRecording", default: false)

    // MARK: Opt-in system states
    static let focusIndicatorEnabled = Key<Bool>("focusIndicatorEnabled", default: false)
    static let focusIndicatorActive = Key<Bool>("focusIndicatorActive", default: false)
    static let focusIndicatorName = Key<String>("focusIndicatorName", default: "Focus")
    static let connectivityActivityEnabled = Key<Bool>("connectivityActivityEnabled", default: false)
    
    // MARK: Appearance
    static let showEmojis = Key<Bool>("showEmojis", default: false)
    //static let alwaysShowTabs = Key<Bool>("alwaysShowTabs", default: true)
    static let showMirror = Key<Bool>("showMirror", default: false)
    static let mirrorShape = Key<MirrorShapeEnum>("mirrorShape", default: MirrorShapeEnum.rectangle)
    static let settingsIconInNotch = Key<Bool>("settingsIconInNotch", default: true)
    static let lightingEffect = Key<Bool>("lightingEffect", default: true)
    static let enableShadow = Key<Bool>("enableShadow", default: true)
    static let cornerRadiusScaling = Key<Bool>("cornerRadiusScaling", default: true)
    static let islandTheme = Key<IslandTheme>("islandTheme", default: .midnight)

    static let showNotHumanFace = Key<Bool>("showNotHumanFace", default: false)
    static let tileShowLabels = Key<Bool>("tileShowLabels", default: false)
    static let showCalendar = Key<Bool>("showCalendar", default: false)
    static let hideCompletedReminders = Key<Bool>("hideCompletedReminders", default: true)
    static let sliderColor = Key<SliderColorEnum>(
        "sliderUseAlbumArtColor",
        default: SliderColorEnum.white
    )
    static let playerColorTinting = Key<Bool>("playerColorTinting", default: true)
    static let useMusicVisualizer = Key<Bool>("useMusicVisualizer", default: true)
    static let customVisualizers = Key<[CustomVisualizer]>("customVisualizers", default: [])
    static let selectedVisualizer = Key<CustomVisualizer?>("selectedVisualizer", default: nil)
    
    // MARK: Gestures
    static let enableGestures = Key<Bool>("enableGestures", default: true)
    static let closeGestureEnabled = Key<Bool>("closeGestureEnabled", default: true)
    static let gestureSensitivity = Key<CGFloat>("gestureSensitivity", default: 200.0)
    
    // MARK: Media playback
    static let coloredSpectrogram = Key<Bool>("coloredSpectrogram", default: true)
    static let enableSneakPeek = Key<Bool>("enableSneakPeek", default: false)
    static let sneakPeekStyles = Key<SneakPeekStyle>("sneakPeekStyles", default: .standard)
    static let waitInterval = Key<Double>("waitInterval", default: 3)
    static let showShuffleAndRepeat = Key<Bool>("showShuffleAndRepeat", default: false)
    static let enableLyrics = Key<Bool>("enableLyrics", default: false)
    static let musicControlSlots = Key<[MusicControlButton]>(
        "musicControlSlots",
        default: MusicControlButton.defaultLayout
    )
    static let musicControlSlotLimit = Key<Int>(
        "musicControlSlotLimit",
        default: MusicControlButton.defaultLayout.count
    )
    
    // MARK: Battery
    static let showPowerStatusNotifications = Key<Bool>("showPowerStatusNotifications", default: true)
    static let showBatteryIndicator = Key<Bool>("showBatteryIndicator", default: true)
    static let showBatteryPercentage = Key<Bool>("showBatteryPercentage", default: true)
    static let showPowerStatusIcons = Key<Bool>("showPowerStatusIcons", default: true)
    
    // MARK: Downloads
    static let enableDownloadListener = Key<Bool>("enableDownloadListener", default: true)
    static let enableSafariDownloads = Key<Bool>("enableSafariDownloads", default: true)
    static let selectedDownloadIndicatorStyle = Key<DownloadIndicatorStyle>("selectedDownloadIndicatorStyle", default: DownloadIndicatorStyle.progress)
    static let selectedDownloadIconStyle = Key<DownloadIconStyle>("selectedDownloadIconStyle", default: DownloadIconStyle.onlyAppIcon)
    
    // MARK: HUD
    static let hudReplacement = Key<Bool>("hudReplacement", default: false)
    static let inlineHUD = Key<Bool>("inlineHUD", default: false)
    static let enableGradient = Key<Bool>("enableGradient", default: false)
    static let systemEventIndicatorShadow = Key<Bool>("systemEventIndicatorShadow", default: false)
    static let systemEventIndicatorUseAccent = Key<Bool>("systemEventIndicatorUseAccent", default: false)
    static let showOpenNotchHUD = Key<Bool>("showOpenNotchHUD", default: true)
    static let showOpenNotchHUDPercentage = Key<Bool>("showOpenNotchHUDPercentage", default: true)
    static let showClosedNotchHUDPercentage = Key<Bool>("showClosedNotchHUDPercentage", default: false)
    // Option key modifier behaviour for media keys
    static let optionKeyAction = Key<OptionKeyAction>("optionKeyAction", default: OptionKeyAction.openSettings)
    
    // MARK: Shelf
    static let boringShelf = Key<Bool>("boringShelf", default: true)
    // Shelf remains an explicit destination. Home is the default hover target
    // so current media and the primary dashboard are never hidden by items.
    static let openShelfByDefault = Key<Bool>("openShelfByDefault", default: false)
    static let shelfTapToOpen = Key<Bool>("shelfTapToOpen", default: true)
    static let quickShareProvider = Key<String>("quickShareProvider", default: QuickShareProvider.defaultProvider.id)
    static let copyOnDrag = Key<Bool>("copyOnDrag", default: false)
    static let autoRemoveShelfItems = Key<Bool>("autoRemoveShelfItems", default: false)
    static let expandedDragDetection = Key<Bool>("expandedDragDetection", default: true)

    // MARK: Clipboard history
    // Fresh installs capture plain copied text by default. Existing stored
    // values are preserved, so a user who turns this off stays opted out.
    static let clipboardHistoryEnabled = Key<Bool>("clipboardHistoryEnabled", default: true)
    static let clipboardHistoryLimit = Key<Int>("clipboardHistoryLimit", default: 20)
    static let clipboardExcludedBundleIdentifiers = Key<String>("clipboardExcludedBundleIdentifiers", default: "")
    static let clipboardCaptureRichText = Key<Bool>("clipboardCaptureRichText", default: false)

    // MARK: Weather
    static let weatherEnabled = Key<Bool>("weatherEnabled", default: false)
    static let weatherLocationMode = Key<WeatherLocationMode>("weatherLocationMode", default: .automatic)
    static let weatherLocationQuery = Key<String>("weatherLocationQuery", default: "")
    static let weatherLocationModeMigrated = Key<Bool>("weatherLocationModeMigrated", default: false)
    static let weatherTemperatureUnit = Key<WeatherTemperatureUnit>("weatherTemperatureUnit", default: .fahrenheit)

    // MARK: Timer
    static let timerCompletionNotifications = Key<Bool>("timerCompletionNotifications", default: true)
    static let timerPresets = Key<[TimerPreset]>("timerPresets", default: [])
    
    // MARK: Calendar
    static let calendarSelectionState = Key<CalendarSelectionState>("calendarSelectionState", default: .all)
    static let hideAllDayEvents = Key<Bool>("hideAllDayEvents", default: false)
    static let showFullEventTitles = Key<Bool>("showFullEventTitles", default: false)
    static let autoScrollToNextEvent = Key<Bool>("autoScrollToNextEvent", default: true)
    
    // MARK: Fullscreen Media Detection
    static let hideNotchOption = Key<HideNotchOption>("hideNotchOption", default: .nowPlayingOnly)
    
    // MARK: Media Controller
    static let mediaController = Key<MediaControllerType>("mediaController", default: defaultMediaController)
    
    // MARK: Advanced Settings
    static let useCustomAccentColor = Key<Bool>("useCustomAccentColor", default: false)
    static let customAccentColorData = Key<Data?>("customAccentColorData", default: nil)
    // Show or hide the title bar
    static let hideTitleBar = Key<Bool>("hideTitleBar", default: true)
    
    // Helper to determine the default media controller based on NowPlaying deprecation status
    static var defaultMediaController: MediaControllerType {
        if MusicManager.shared.isNowPlayingDeprecated {
            return .appleMusic
        } else {
            return .nowPlaying
        }
    }

    static let didClearLegacyURLCacheV1 = Key<Bool>("didClearLegacyURLCache_v1", default: false)
}

/// One typed migration gate for persisted values shared by every native window.
/// Sliders constrain new input; this normalizes legacy/external defaults before use.
enum SettingsMigration {
    static let currentSchemaVersion = 1

    static func apply() {
        normalizeBounds()
        if Defaults[.settingsSchemaVersion] < currentSchemaVersion {
            Defaults[.settingsSchemaVersion] = currentSchemaVersion
        }
    }

    static func resetAppearanceAndInteraction() {
        Defaults[.islandTheme] = .midnight
        Defaults[.useCustomAccentColor] = false
        Defaults[.customAccentColorData] = nil
        Defaults[.showMirror] = false
        Defaults[.mirrorShape] = .rectangle
        Defaults[.enableShadow] = true
        Defaults[.cornerRadiusScaling] = true
        Defaults[.settingsIconInNotch] = true
        Defaults[.notchHeightMode] = .matchRealNotchSize
        Defaults[.nonNotchHeightMode] = .matchMenuBar
        Defaults[.notchHeight] = 32
        Defaults[.nonNotchHeight] = 32
        Defaults[.openNotchOnHover] = true
        Defaults[.minimumHoverDuration] = 0.3
        Defaults[.enableGestures] = true
        Defaults[.closeGestureEnabled] = true
        Defaults[.gestureSensitivity] = 200
        normalizeBounds()
        NotificationCenter.default.post(name: .notchHeightChanged, object: nil)
    }

    private static func normalizeBounds() {
        Defaults[.notchHeight] = min(max(Defaults[.notchHeight], 15), 45)
        Defaults[.nonNotchHeight] = min(max(Defaults[.nonNotchHeight], 16), 40)
        Defaults[.minimumHoverDuration] = min(max(Defaults[.minimumHoverDuration], 0), 1)
        Defaults[.gestureSensitivity] = min(max(Defaults[.gestureSensitivity], 100), 300)
        Defaults[.waitInterval] = min(max(Defaults[.waitInterval], 0), 10)
        Defaults[.musicControlSlotLimit] = min(max(Defaults[.musicControlSlotLimit], 1), MusicControlButton.defaultLayout.count)
    }
}
