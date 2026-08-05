//
//  BoringViewCoordinator.swift
//  boringNotch
//
//  Created by Alexander on 2024-11-20.
//

import AppKit
import Combine
@preconcurrency import CoreLocation
import Defaults
import Network
import SwiftUI
import UserNotifications

typealias WeatherDataLoader = @Sendable (URL) async throws -> (Data, URLResponse)

enum WeatherLocationRequest: Equatable {
    case currentLocation
    case city(String)

    init?(mode: WeatherLocationMode, cityQuery: String) {
        switch mode {
        case .automatic:
            self = .currentLocation
        case .custom:
            let city = cityQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !city.isEmpty else { return nil }
            self = .city(city)
        }
    }
}

private enum WeatherLocationError: LocalizedError {
    case servicesDisabled
    case accessDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .servicesDisabled: "Location Services is turned off"
        case .accessDenied: "Allow Location Services for automatic weather"
        case .unavailable: "Current location is unavailable"
        }
    }
}

@MainActor
private final class CurrentWeatherLocationResolver: NSObject, @MainActor CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func currentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw WeatherLocationError.servicesDisabled
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(12))
                guard !Task.isCancelled else { return }
                self?.finish(.failure(WeatherLocationError.unavailable))
            }
            requestLocationIfAuthorized()
        }
    }

    /// Requests only Location Services authorization for first-run onboarding.
    /// It intentionally does not begin a location read or weather refresh.
    func requestAuthorization() async {
        guard CLLocationManager.locationServicesEnabled() else { return }
        guard manager.authorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocationIfAuthorized() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(WeatherLocationError.accessDenied))
        @unknown default:
            finish(.failure(WeatherLocationError.unavailable))
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if let authorizationContinuation {
            self.authorizationContinuation = nil
            authorizationContinuation.resume()
            return
        }
        requestLocationIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(.failure(WeatherLocationError.unavailable))
            return
        }
        finish(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(with: result)
    }
}

struct PersistedCountdownTimer: Codable, Equatable {
    let endDate: Date?
    let pausedRemaining: TimeInterval?

    static func running(until endDate: Date) -> Self {
        Self(endDate: endDate, pausedRemaining: nil)
    }

    static func paused(remaining: TimeInterval) -> Self {
        Self(endDate: nil, pausedRemaining: max(0, remaining))
    }

    func remaining(at date: Date) -> TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(date)) }
        return max(0, pausedRemaining ?? 0)
    }
}

enum TimerCompletionNotification {
    static let identifier = "macisland.countdown-complete"
    static let presentationOptions: UNNotificationPresentationOptions = [.banner, .list, .sound]

    static func content() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Timer finished"
        content.body = "Your MacIsland countdown is complete."
        content.sound = .default
        return content
    }

    static func installForegroundDelivery() {
        UNUserNotificationCenter.current().delegate = TimerCompletionNotificationDelegate.shared
    }
}

@MainActor
enum TimerCompletionFeedback {
    private static var alarmSound: NSSound?
    static var suppressPlaybackForTesting = false
    static let alarmResourceName = "TimerAlarm"

    /// An alarm is distinct from a notification: it continues until the user
    /// acknowledges the completed timer, even when notification delivery is
    /// disabled or delayed by macOS.
    static func startAlarm() {
        guard !suppressPlaybackForTesting else { return }
        stopAlarm()

        // This is a bundled, public-license asset mastered for a clear alarm
        // attack. It avoids private Clock/iPhone resources and the relatively
        // quiet, user-configurable macOS alert sounds.
        guard let url = Bundle.main.url(forResource: alarmResourceName, withExtension: "wav"),
              let sound = NSSound(contentsOf: url, byReference: true) else {
            NSSound.beep()
            return
        }

        sound.loops = true
        sound.volume = 1
        alarmSound = sound
        sound.play()
    }

    static func stopAlarm() {
        alarmSound?.stop()
        alarmSound = nil
    }
}

struct TimerPausedMedia: Equatable {
    let source: MediaControllerType
    let bundleIdentifier: String?
}

enum TimerCompletionMediaPolicy {
    static func shouldResume(
        pausedMedia: TimerPausedMedia?,
        currentSource: MediaControllerType,
        currentBundleIdentifier: String?
    ) -> Bool {
        guard let pausedMedia, pausedMedia.source == currentSource else {
            return false
        }
        return pausedMedia.bundleIdentifier == nil
            || pausedMedia.bundleIdentifier == currentBundleIdentifier
    }
}

private final class TimerCompletionNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TimerCompletionNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.identifier == TimerCompletionNotification.identifier else {
            completionHandler([])
            return
        }
        completionHandler(TimerCompletionNotification.presentationOptions)
    }
}

enum SneakContentType: Equatable {
    case brightness
    case volume
    case backlight
    case music
    case mic
    case battery
    case download
    case focus
    case connectivity

    var requiresHUDReplacement: Bool {
        switch self {
        case .volume, .brightness, .backlight, .mic:
            true
        case .music, .battery, .download, .focus, .connectivity:
            false
        }
    }

    var isSystemState: Bool {
        self == .focus || self == .connectivity
    }
}

enum ConnectivityState: Equatable {
    case unknown
    case online
    case offline

    init(pathStatus: NWPath.Status) {
        self = pathStatus == .satisfied ? .online : .offline
    }
}

enum SystemStatePresentation {
    static func focusName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Focus" : String(trimmed.prefix(30))
    }

    static func title(for type: SneakContentType, value: CGFloat) -> String {
        switch type {
        case .focus:
            return focusName(Defaults[.focusIndicatorName])
        case .connectivity:
            return value > 0 ? "Connected" : "Offline"
        default:
            return ""
        }
    }

    static func detail(for type: SneakContentType, value: CGFloat) -> String {
        switch type {
        case .focus:
            return value > 0 ? "Focus started" : "Focus ended"
        case .connectivity:
            return value > 0 ? "Internet connection restored" : "No internet connection"
        default:
            return ""
        }
    }

    static func symbol(for type: SneakContentType, value: CGFloat) -> String {
        switch type {
        case .focus:
            return value > 0 ? "moon.fill" : "moon"
        case .connectivity:
            return value > 0 ? "wifi" : "wifi.slash"
        default:
            return "circle"
        }
    }
}

struct sneakPeek {
    var show: Bool = false
    var type: SneakContentType = .music
    var value: CGFloat = 0
    var icon: String = ""
}

struct SharedSneakPeek: Codable {
    var show: Bool
    var type: String
    var value: String
    var icon: String
}

enum BrowserType {
    case chromium
    case safari
}

enum IslandTimerStatus: Equatable {
    case idle
    case running
    case paused
    case completed

    var isVisible: Bool { self != .idle }
}

enum IslandTimerMode: Equatable {
    case countdown
    case stopwatch
}

enum WeatherStatus: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
}

struct WeatherSnapshot: Codable, Equatable {
    let location: String
    let temperatureCelsius: Double
    let weatherCode: Int
    let updatedAt: Date

    func formattedTemperature(in unit: WeatherTemperatureUnit) -> String {
        let value = switch unit {
        case .celsius: temperatureCelsius
        case .fahrenheit: temperatureCelsius * 9 / 5 + 32
        }
        return "\(Int(value.rounded()))°\(unit == .celsius ? "C" : "F")"
    }
}

struct ExpandedItem {
    var show: Bool = false
    var type: SneakContentType = .battery
    var value: CGFloat = 0
    var browser: BrowserType = .chromium
}

private enum PendingIslandActivity {
    case sneakPeek(type: SneakContentType, duration: TimeInterval, value: CGFloat, icon: String)
    case expanded(type: SneakContentType, value: CGFloat, browser: BrowserType)

    var type: SneakContentType {
        switch self {
        case .sneakPeek(let type, _, _, _), .expanded(let type, _, _): type
        }
    }
}

struct ClipboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let capturedAt: Date

    init(text: String, capturedAt: Date = .now) {
        id = UUID()
        self.text = text
        self.capturedAt = capturedAt
    }
}

private struct WeatherGeocodingResponse: Decodable {
    struct Location: Decodable {
        let latitude: Double
        let longitude: Double
    }

    let results: [Location]?
}

private struct WeatherForecastResponse: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    let current: Current?
}

@MainActor
class BoringViewCoordinator: ObservableObject {
    static let shared = BoringViewCoordinator()

    @Published var currentView: NotchViews = .home
    @Published private(set) var timerStatus: IslandTimerStatus = .idle
    @Published private(set) var timerMode: IslandTimerMode = .countdown
    @Published private(set) var timerRemaining: TimeInterval = 0
    @Published private(set) var stopwatchElapsed: TimeInterval = 0
    @Published private(set) var clipboardEntries: [ClipboardEntry] = []
    private var auditClipboardEntriesActive = false
    @Published private(set) var weatherStatus: WeatherStatus = .idle
    @Published private(set) var weatherSnapshot: WeatherSnapshot?
    @Published private(set) var connectivityState: ConnectivityState = .unknown
    @Published private(set) var focusIndicatorActive = Defaults[.focusIndicatorActive]
    @Published var helloAnimationRunning: Bool = false
    private var sneakPeekDispatch: DispatchWorkItem?
    private var expandingViewDispatch: DispatchWorkItem?
    private var hudEnableTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var timerNotificationTask: Task<Void, Never>?
    private var timerNotificationScheduleID = UUID()
    private var timerEndDate: Date?
    private var mediaPausedForTimerAlarm: TimerPausedMedia?
    private var pendingActivities: [PendingIslandActivity] = []
    private var stopwatchStartedAt: Date?
    private var stopwatchAccumulatedElapsed: TimeInterval = 0
    private var clipboardMonitorTask: Task<Void, Never>?
    private var weatherRefreshTask: Task<Void, Never>?
    private var weatherRefreshLoopTask: Task<Void, Never>?
    private var currentWeatherLocationResolver: CurrentWeatherLocationResolver?
    private var weatherRefreshID = UUID()
    private var connectivityMonitor: NWPathMonitor?
    private let connectivityQueue = DispatchQueue(label: "com.macisland.connectivity", qos: .utility)
    private var hasReceivedConnectivityState = false
    private var systemStatesSuspended = false
    private var clipboardChangeCount = NSPasteboard.general.changeCount
    private let clipboardStorageKey = "clipboardHistoryEntriesV1"
    private let weatherStorageKey = "weatherSnapshotV1"
    private let countdownTimerStorageKey = "countdownTimerV1"
    private let weatherCacheLifetime: TimeInterval = 15 * 60
    private let weatherRefreshInterval: Duration = .seconds(30 * 60)
    private var cancellables = Set<AnyCancellable>()

    @AppStorage("firstLaunch") var firstLaunch: Bool = true
    @AppStorage("showWhatsNew") var showWhatsNew: Bool = true
    @AppStorage("musicLiveActivityEnabled") var musicLiveActivityEnabled: Bool = true
    @AppStorage("currentMicStatus") var currentMicStatus: Bool = true

    /// First-run onboarding asks before automatic weather needs this permission;
    /// a later weather refresh remains the fallback for existing installations.
    func requestWeatherLocationPermission() async {
        let resolver = CurrentWeatherLocationResolver()
        currentWeatherLocationResolver = resolver
        await resolver.requestAuthorization()
        if currentWeatherLocationResolver === resolver {
            currentWeatherLocationResolver = nil
        }
    }

    /// Timer completion keeps this authorization request out of an active timer
    /// flow for new users. Existing installs still request on first timer use.
    func requestTimerNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    @AppStorage("alwaysShowTabs") var alwaysShowTabs: Bool = true {
        didSet {
            if !alwaysShowTabs {
                openLastTabByDefault = false
                if ShelfStateViewModel.shared.isEmpty || !Defaults[.openShelfByDefault] {
                    currentView = .home
                }
            }
        }
    }

    @AppStorage("openLastTabByDefault") var openLastTabByDefault: Bool = false {
        didSet {
            if openLastTabByDefault {
                alwaysShowTabs = true
            }
        }
    }
    
    @Default(.hudReplacement) var hudReplacement: Bool
    
    // Legacy storage for migration
    @AppStorage("preferred_screen_name") private var legacyPreferredScreenName: String?
    
    // New UUID-based storage
    @AppStorage("preferred_screen_uuid") var preferredScreenUUID: String? {
        didSet {
            if let uuid = preferredScreenUUID {
                selectedScreenUUID = uuid
            }
            NotificationCenter.default.post(name: Notification.Name.selectedScreenChanged, object: nil)
        }
    }

    @Published var selectedScreenUUID: String = NSScreen.main?.displayUUID ?? ""

    @Published var optionKeyPressed: Bool = true
    private var accessibilityObserver: Any?
    private var hudReplacementCancellable: AnyCancellable?

    private init() {
        TimerCompletionNotification.installForegroundDelivery()
        migrateWeatherLocationPreferenceIfNeeded()
        // Perform migration from name-based to UUID-based storage
        if preferredScreenUUID == nil, let legacyName = legacyPreferredScreenName {
            // Try to find screen by name and migrate to UUID
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                preferredScreenUUID = uuid
                NSLog("✅ Migrated display preference from name '\(legacyName)' to UUID '\(uuid)'")
            } else {
                // Fallback to main screen if legacy screen not found
                preferredScreenUUID = NSScreen.main?.displayUUID
                NSLog("⚠️ Could not find display named '\(legacyName)', falling back to main screen")
            }
            // Clear legacy value after migration
            legacyPreferredScreenName = nil
        } else if preferredScreenUUID == nil {
            // No legacy value, use main screen
            preferredScreenUUID = NSScreen.main?.displayUUID
        }
        
        selectedScreenUUID = preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""
        configureSystemStateMonitoring()
        // Observe changes to accessibility authorization and react accordingly
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.accessibilityAuthorizationChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if Defaults[.hudReplacement] {
                    await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
                }
            }
        }

        // Observe changes to hudReplacement
        hudReplacementCancellable = Defaults.publisher(.hudReplacement)
            .sink { [weak self] change in
                Task { @MainActor in
                    guard let self = self else { return }

                    self.hudEnableTask?.cancel()
                    self.hudEnableTask = nil

                    if change.newValue {
                        self.hudEnableTask = Task { @MainActor in
                            let granted = await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
                            if Task.isCancelled { return }

                            if granted {
                                await MediaKeyInterceptor.shared.start()
                            } else {
                                Defaults[.hudReplacement] = false
                            }
                        }
                    } else {
                        MediaKeyInterceptor.shared.stop()
                    }
                }
        }

        Task { @MainActor in
            // First-run onboarding owns attention. Running a second decorative
            // notch animation at the same time obscures the native setup window.
            helloAnimationRunning = false

            if Defaults[.hudReplacement] {
                let authorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
                if !authorized {
                    Defaults[.hudReplacement] = false
                } else {
                    await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
                }
            }
        }

        Defaults.publisher(.clipboardHistoryEnabled)
            .sink { [weak self] change in
                Task { @MainActor in
                    self?.setClipboardMonitoring(enabled: change.newValue)
                }
            }
            .store(in: &cancellables)
        loadClipboardEntries()
        setClipboardMonitoring(enabled: Defaults[.clipboardHistoryEnabled])
        loadWeatherSnapshot()
        // Weather refreshes on app startup (and from its explicit Settings
        // controls), never because the Home page happens to reappear.
        refreshWeather()
        startWeatherRefreshLoop()
        restoreCountdownTimer()
    }

    private func configureSystemStateMonitoring() {
        Defaults.publisher(.connectivityActivityEnabled)
            .map(\.newValue)
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.startConnectivityMonitoring()
                } else {
                    self.stopConnectivityMonitoring()
                }
            }
            .store(in: &cancellables)

        Defaults.publisher(.focusIndicatorActive)
            .map(\.newValue)
            .removeDuplicates()
            .sink { [weak self] active in
                self?.focusIndicatorDidChange(active)
            }
            .store(in: &cancellables)

        if Defaults[.connectivityActivityEnabled] {
            startConnectivityMonitoring()
        }
    }

    func setSystemStatesSuspended(_ suspended: Bool) {
        systemStatesSuspended = suspended
        if suspended {
            stopConnectivityMonitoring()
        } else if Defaults[.connectivityActivityEnabled] {
            startConnectivityMonitoring()
        }
    }

    private func startConnectivityMonitoring() {
        guard connectivityMonitor == nil, !systemStatesSuspended else { return }
        hasReceivedConnectivityState = false
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let state = ConnectivityState(pathStatus: path.status)
            Task { @MainActor in
                self?.connectivityDidChange(to: state)
            }
        }
        connectivityMonitor = monitor
        monitor.start(queue: connectivityQueue)
    }

    private func stopConnectivityMonitoring() {
        connectivityMonitor?.cancel()
        connectivityMonitor = nil
        hasReceivedConnectivityState = false
        connectivityState = .unknown
    }

    private func connectivityDidChange(to state: ConnectivityState) {
        let wasInitialized = hasReceivedConnectivityState
        let didChange = connectivityState != state
        connectivityState = state
        hasReceivedConnectivityState = true

        guard wasInitialized, didChange,
              Defaults[.connectivityActivityEnabled], !systemStatesSuspended else { return }
        toggleSneakPeek(
            status: true,
            type: .connectivity,
            duration: 3,
            value: state == .online ? 1 : 0
        )
    }

    private func focusIndicatorDidChange(_ active: Bool) {
        focusIndicatorActive = active
        guard Defaults[.focusIndicatorEnabled], !systemStatesSuspended else { return }
        toggleSneakPeek(status: true, type: .focus, duration: 3, value: active ? 1 : 0)
    }

    func setFocusIndicatorActive(_ active: Bool) {
        Defaults[.focusIndicatorActive] = active
    }

    /// Refreshes weather while preserving a usable forecast during background
    /// work. A foreground caller can still opt into an explicit loading state
    /// when no forecast exists yet.
    func refreshWeather(force: Bool = false, silently: Bool = false) {
        weatherRefreshTask?.cancel()
        weatherRefreshTask = nil
        weatherRefreshID = UUID()

        guard Defaults[.weatherEnabled] else {
            weatherStatus = .idle
            return
        }

        let mode = Defaults[.weatherLocationMode]
        let cityQuery = Defaults[.weatherLocationQuery]
        guard let request = WeatherLocationRequest(mode: mode, cityQuery: cityQuery) else {
            weatherStatus = .failed("Choose a city in Settings")
            return
        }

        let refreshID = weatherRefreshID
        let preservesVisibleForecast = silently && weatherSnapshot != nil
        if !preservesVisibleForecast {
            weatherStatus = .loading
        }
        weatherRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let resolved: (coordinate: (latitude: Double, longitude: Double), displayName: String)
                switch request {
                case .currentLocation:
                    resolved = try await self.resolveCurrentWeatherLocation()
                case .city(let city):
                    resolved = (try await Self.resolveWeatherLocation(named: city), city)
                }

                if !force, let weatherSnapshot,
                   Self.isWeatherCacheFresh(
                       weatherSnapshot,
                       for: resolved.displayName,
                       now: .now,
                       lifetime: self.weatherCacheLifetime
                   )
                {
                    self.weatherStatus = .ready
                    self.weatherRefreshTask = nil
                    return
                }

                let snapshot = try await Self.fetchWeather(for: resolved.coordinate, displayName: resolved.displayName)
                guard !Task.isCancelled,
                      self.weatherRefreshID == refreshID,
                      Defaults[.weatherEnabled],
                      Defaults[.weatherLocationMode] == mode,
                      (mode == .automatic || Self.normalizedWeatherLocation(Defaults[.weatherLocationQuery]) == Self.normalizedWeatherLocation(cityQuery))
                else { return }
                self.weatherSnapshot = snapshot
                self.weatherStatus = .ready
                self.saveWeatherSnapshot(snapshot)
                self.weatherRefreshTask = nil
            } catch {
                guard !Task.isCancelled, self.weatherRefreshID == refreshID else { return }
                // A background refresh should not turn a previously useful
                // forecast into a transient error surface. The next scheduled
                // refresh can recover normally.
                if !preservesVisibleForecast {
                    self.weatherStatus = .failed((error as? LocalizedError)?.errorDescription ?? "Weather unavailable")
                } else {
                    self.weatherStatus = .ready
                }
                self.weatherRefreshTask = nil
            }
        }
    }

    private func startWeatherRefreshLoop() {
        guard weatherRefreshLoopTask == nil else { return }
        weatherRefreshLoopTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: self.weatherRefreshInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self.refreshWeather(force: true, silently: true)
            }
        }
    }

    private func migrateWeatherLocationPreferenceIfNeeded() {
        guard !Defaults[.weatherLocationModeMigrated] else { return }
        if !Defaults[.weatherLocationQuery].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Defaults[.weatherLocationMode] = .custom
        }
        Defaults[.weatherLocationModeMigrated] = true
    }

    static func isWeatherCacheFresh(
        _ snapshot: WeatherSnapshot,
        for location: String,
        now: Date,
        lifetime: TimeInterval
    ) -> Bool {
        normalizedWeatherLocation(snapshot.location) == normalizedWeatherLocation(location)
            && now.timeIntervalSince(snapshot.updatedAt) < lifetime
    }

    private static func normalizedWeatherLocation(_ location: String) -> String {
        location.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }

    private func loadWeatherSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: weatherStorageKey),
              let snapshot = try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
        else { return }
        weatherSnapshot = snapshot
        weatherStatus = .ready
    }

    private func saveWeatherSnapshot(_ snapshot: WeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: weatherStorageKey)
    }

    static func resolveWeatherLocation(
        named name: String,
        dataLoader: WeatherDataLoader = { try await URLSession.shared.data(from: $0) }
    ) async throws -> (latitude: Double, longitude: Double) {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let (data, response) = try await dataLoader(components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let result = try JSONDecoder().decode(WeatherGeocodingResponse.self, from: data)
        guard let location = result.results?.first else { throw URLError(.cannotFindHost) }
        return (location.latitude, location.longitude)
    }

    private func resolveCurrentWeatherLocation() async throws -> (coordinate: (latitude: Double, longitude: Double), displayName: String) {
        let resolver = CurrentWeatherLocationResolver()
        currentWeatherLocationResolver = resolver
        defer {
            if currentWeatherLocationResolver === resolver {
                currentWeatherLocationResolver = nil
            }
        }
        let location = try await resolver.currentLocation()
        let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first
        let displayName = [placemark?.locality, placemark?.administrativeArea, placemark?.country]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty }) ?? "Current Location"
        return ((location.coordinate.latitude, location.coordinate.longitude), displayName)
    }

    static func fetchWeather(
        for coordinate: (latitude: Double, longitude: Double),
        displayName: String,
        dataLoader: WeatherDataLoader = { try await URLSession.shared.data(from: $0) }
    ) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
        ]
        let (data, response) = try await dataLoader(components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let result = try JSONDecoder().decode(WeatherForecastResponse.self, from: data)
        guard let current = result.current else { throw URLError(.badServerResponse) }
        return WeatherSnapshot(
            location: displayName,
            temperatureCelsius: current.temperature2m,
            weatherCode: current.weatherCode,
            updatedAt: .now
        )
    }

    func copyClipboardEntry(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        clipboardChangeCount = pasteboard.changeCount
    }

    func useAuditClipboardEntries(_ entries: [ClipboardEntry]) {
        auditClipboardEntriesActive = true
        clipboardEntries = entries
    }

    func removeClipboardEntry(_ entry: ClipboardEntry) {
        clipboardEntries.removeAll { $0.id == entry.id }
        saveClipboardEntries()
    }

    func clearClipboardHistory() {
        clipboardEntries = []
        saveClipboardEntries()
    }

    func recordClipboardText(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Defaults[.clipboardHistoryEnabled], !normalized.isEmpty,
              normalized.count <= 10_000,
              Self.shouldCaptureClipboard(
                  frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                  excludedBundleIdentifiers: Defaults[.clipboardExcludedBundleIdentifiers]
              )
        else { return }

        clipboardEntries.removeAll { $0.text == normalized }
        clipboardEntries.insert(ClipboardEntry(text: normalized), at: 0)
        let limit = min(max(Defaults[.clipboardHistoryLimit], 1), 100)
        clipboardEntries = Array(clipboardEntries.prefix(limit))
        saveClipboardEntries()
    }

    private func setClipboardMonitoring(enabled: Bool) {
        clipboardMonitorTask?.cancel()
        clipboardMonitorTask = nil
        clipboardChangeCount = NSPasteboard.general.changeCount
        guard enabled else { return }

        clipboardMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                self?.captureClipboardIfChanged()
            }
        }
    }

    private func captureClipboardIfChanged() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != clipboardChangeCount else { return }
        clipboardChangeCount = pasteboard.changeCount
        guard Self.shouldCaptureClipboard(
            types: pasteboard.types ?? [],
            allowsRichText: Defaults[.clipboardCaptureRichText]
        ) else { return }
        guard let text = pasteboard.string(forType: .string) else { return }
        recordClipboardText(text)
    }

    static func shouldCaptureClipboard(
        types: [NSPasteboard.PasteboardType],
        allowsRichText: Bool
    ) -> Bool {
        guard types.contains(.string) else { return false }
        guard allowsRichText else {
            return !types.contains(.rtf) && !types.contains(.html)
        }
        return true
    }

    static func shouldCaptureClipboard(
        frontmostBundleIdentifier: String?,
        excludedBundleIdentifiers: String
    ) -> Bool {
        guard let frontmostBundleIdentifier else { return true }
        let excluded = Set(
            excludedBundleIdentifiers
                .split(whereSeparator: { $0 == "," || $0 == "\n" })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
        return !excluded.contains(frontmostBundleIdentifier.lowercased())
    }

    private func loadClipboardEntries() {
        guard let data = UserDefaults.standard.data(forKey: clipboardStorageKey),
              let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        else { return }
        let limit = min(max(Defaults[.clipboardHistoryLimit], 1), 100)
        clipboardEntries = Array(decoded.prefix(limit))
    }

    private func saveClipboardEntries() {
        guard !auditClipboardEntriesActive else { return }
        guard let data = try? JSONEncoder().encode(clipboardEntries) else { return }
        UserDefaults.standard.set(data, forKey: clipboardStorageKey)
    }

    func startTimer(seconds: TimeInterval) {
        resumeMediaPausedForTimerAlarm()
        TimerCompletionFeedback.stopAlarm()
        let clampedSeconds = max(1, seconds)
        timerTask?.cancel()
        timerMode = .countdown
        timerRemaining = clampedSeconds
        stopwatchElapsed = 0
        stopwatchAccumulatedElapsed = 0
        stopwatchStartedAt = nil
        timerEndDate = Date().addingTimeInterval(clampedSeconds)
        timerStatus = .running
        persistCountdownTimer()
        if let timerEndDate {
            scheduleTimerCompletionNotification(at: timerEndDate)
        }
        scheduleTimerUpdates()
    }

    func startStopwatch() {
        resumeMediaPausedForTimerAlarm()
        TimerCompletionFeedback.stopAlarm()
        timerTask?.cancel()
        clearPersistedCountdownTimer()
        cancelTimerCompletionNotification()
        timerMode = .stopwatch
        timerRemaining = 0
        stopwatchElapsed = 0
        stopwatchAccumulatedElapsed = 0
        stopwatchStartedAt = .now
        timerEndDate = nil
        timerStatus = .running
        scheduleTimerUpdates()
    }

    func toggleTimerPause() {
        switch timerStatus {
        case .running:
            updateTimer()
            timerTask?.cancel()
            timerTask = nil
            if timerMode == .countdown {
                timerEndDate = nil
                timerStatus = .paused
                persistCountdownTimer()
                cancelTimerCompletionNotification()
            } else {
                stopwatchAccumulatedElapsed = stopwatchElapsed
                stopwatchStartedAt = nil
                timerStatus = .paused
            }
        case .paused:
            if timerMode == .countdown {
                timerEndDate = Date().addingTimeInterval(timerRemaining)
                timerStatus = .running
                persistCountdownTimer()
                if let timerEndDate {
                    scheduleTimerCompletionNotification(at: timerEndDate)
                }
            } else {
                stopwatchStartedAt = .now
                timerStatus = .running
            }
            scheduleTimerUpdates()
        case .idle, .completed:
            break
        }
    }

    func stopTimer() {
        TimerCompletionFeedback.stopAlarm()
        resumeMediaPausedForTimerAlarm()
        timerTask?.cancel()
        timerTask = nil
        timerEndDate = nil
        stopwatchStartedAt = nil
        stopwatchAccumulatedElapsed = 0
        timerRemaining = 0
        stopwatchElapsed = 0
        timerMode = .countdown
        timerStatus = .idle
        clearPersistedCountdownTimer()
        cancelTimerCompletionNotification()
    }

    func updateTimerNotificationPreference() {
        guard Defaults[.timerCompletionNotifications],
              timerMode == .countdown,
              timerStatus == .running,
              let timerEndDate
        else {
            cancelTimerCompletionNotification()
            return
        }
        scheduleTimerCompletionNotification(at: timerEndDate)
    }

    private func scheduleTimerUpdates() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                self?.updateTimer()
            }
        }
    }

    private func updateTimer() {
        guard timerStatus == .running else { return }
        switch timerMode {
        case .countdown:
            guard let timerEndDate else { return }
            timerRemaining = max(0, timerEndDate.timeIntervalSinceNow)
            guard timerRemaining == 0 else { return }

            timerTask?.cancel()
            timerTask = nil
            self.timerEndDate = nil
            timerStatus = .completed
            clearPersistedCountdownTimer()
            // Pause the active source MacIsland already controls before the
            // retained alarm begins. Arbitrary third-party audio cannot be
            // stopped with public macOS APIs, but Apple Music, Spotify, and
            // supported Now Playing sources follow this path.
            if !TimerCompletionFeedback.suppressPlaybackForTesting,
               MusicManager.shared.isPlaying {
                mediaPausedForTimerAlarm = TimerPausedMedia(
                    source: MusicManager.shared.activeMediaSource,
                    bundleIdentifier: MusicManager.shared.bundleIdentifier
                )
                MusicManager.shared.pause()
            }
            TimerCompletionFeedback.startAlarm()
            NSApp.requestUserAttention(.informationalRequest)
        case .stopwatch:
            guard let stopwatchStartedAt else { return }
            stopwatchElapsed = stopwatchAccumulatedElapsed + Date().timeIntervalSince(stopwatchStartedAt)
        }
    }

    private func resumeMediaPausedForTimerAlarm() {
        defer { mediaPausedForTimerAlarm = nil }
        guard TimerCompletionMediaPolicy.shouldResume(
            pausedMedia: mediaPausedForTimerAlarm,
            currentSource: MusicManager.shared.activeMediaSource,
            currentBundleIdentifier: MusicManager.shared.bundleIdentifier
        ) else { return }

        MusicManager.shared.play()
    }

    private func restoreCountdownTimer() {
        guard let data = UserDefaults.standard.data(forKey: countdownTimerStorageKey),
              let stored = try? JSONDecoder().decode(PersistedCountdownTimer.self, from: data)
        else { return }

        let remaining = stored.remaining(at: .now)
        guard remaining > 0 else {
            clearPersistedCountdownTimer()
            return
        }

        timerMode = .countdown
        timerRemaining = remaining
        if let endDate = stored.endDate {
            timerEndDate = endDate
            timerStatus = .running
            scheduleTimerCompletionNotification(at: endDate)
            scheduleTimerUpdates()
        } else {
            timerEndDate = nil
            timerStatus = .paused
        }
    }

    private func persistCountdownTimer() {
        guard timerMode == .countdown else { return }
        let state: PersistedCountdownTimer
        switch timerStatus {
        case .running:
            guard let timerEndDate else { return }
            state = .running(until: timerEndDate)
        case .paused:
            state = .paused(remaining: timerRemaining)
        case .idle, .completed:
            clearPersistedCountdownTimer()
            return
        }
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: countdownTimerStorageKey)
    }

    private func clearPersistedCountdownTimer() {
        UserDefaults.standard.removeObject(forKey: countdownTimerStorageKey)
    }

    private func scheduleTimerCompletionNotification(at endDate: Date) {
        guard Defaults[.timerCompletionNotifications] else { return }
        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        timerNotificationTask?.cancel()
        let scheduleID = UUID()
        timerNotificationScheduleID = scheduleID
        timerNotificationTask = Task { [weak self] in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let authorized: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                authorized = true
            case .notDetermined:
                authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            case .denied:
                authorized = false
            @unknown default:
                authorized = false
            }
            guard authorized, !Task.isCancelled,
                  self?.timerNotificationScheduleID == scheduleID
            else { return }

            let request = UNNotificationRequest(
                identifier: TimerCompletionNotification.identifier,
                content: TimerCompletionNotification.content(),
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
            )
            guard !Task.isCancelled,
                  self?.timerNotificationScheduleID == scheduleID
            else { return }
            try? await center.add(request)
        }
    }

    private func cancelTimerCompletionNotification() {
        timerNotificationTask?.cancel()
        timerNotificationTask = nil
        timerNotificationScheduleID = UUID()
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [TimerCompletionNotification.identifier]
        )
    }
    
    @objc func sneakPeekEvent(_ notification: Notification) {
        let decoder = JSONDecoder()
        if let decodedData = try? decoder.decode(
            SharedSneakPeek.self, from: notification.userInfo?.first?.value as! Data)
        {
            let contentType =
                decodedData.type == "brightness"
                ? SneakContentType.brightness
                : decodedData.type == "volume"
                    ? SneakContentType.volume
                    : decodedData.type == "backlight"
                        ? SneakContentType.backlight
                        : decodedData.type == "mic"
                            ? SneakContentType.mic : SneakContentType.brightness

            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .decimal
            let value = CGFloat((formatter.number(from: decodedData.value) ?? 0.0).floatValue)
            let icon = decodedData.icon

            print("Decoded: \(decodedData), Parsed value: \(value)")

            toggleSneakPeek(status: decodedData.show, type: contentType, value: value, icon: icon)

        } else {
            print("Failed to decode JSON data")
        }
    }

    func toggleSneakPeek(
        status: Bool, type: SneakContentType, duration: TimeInterval = 1.5, value: CGFloat = 0,
        icon: String = ""
    ) {
        guard status || (sneakPeek.show && sneakPeek.type == type) else { return }
        sneakPeekDuration = duration
        if type.requiresHUDReplacement {
            // close()
            if !Defaults[.hudReplacement] {
                return
            }
        }
        if status, !canPresent(type: type) {
            enqueue(.sneakPeek(type: type, duration: duration, value: value, icon: icon))
            return
        }
        if status, expandingView.show, activityPriority(for: type) > activityPriority(for: expandingView.type) {
            performActivityHandoff {
                toggleExpandingView(status: false, type: expandingView.type)
            }
        }

        withAnimation(IslandMotion.content) {
            sneakPeek.show = status
            sneakPeek.type = type
            sneakPeek.value = value
            sneakPeek.icon = icon
        }

        if type == .mic {
            currentMicStatus = value == 1
        }
    }

    private var sneakPeekDuration: TimeInterval = 1.5
    private var sneakPeekTask: Task<Void, Never>?
    // A preemption must not drain queued work before its replacement is visible.
    private var isHandingOffActivity = false

    // Helper function to manage sneakPeek timer using Swift Concurrency
    private func scheduleSneakPeekHide(after duration: TimeInterval) {
        sneakPeekTask?.cancel()

        sneakPeekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self = self, !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(IslandMotion.content) {
                    self.toggleSneakPeek(status: false, type: self.sneakPeek.type)
                    self.sneakPeekDuration = 1.5
                }
            }
        }
    }

    @Published var sneakPeek: sneakPeek = .init() {
        didSet {
            if sneakPeek.show {
                scheduleSneakPeekHide(after: sneakPeekDuration)
            } else {
                sneakPeekTask?.cancel()
                if !isHandingOffActivity {
                    presentNextActivityIfPossible()
                }
            }
        }
    }

    func toggleExpandingView(
        status: Bool,
        type: SneakContentType,
        value: CGFloat = 0,
        browser: BrowserType = .chromium
    ) {
        guard status || (expandingView.show && expandingView.type == type) else { return }
        if status, !canPresent(type: type) {
            enqueue(.expanded(type: type, value: value, browser: browser))
            return
        }
        if status, sneakPeek.show, activityPriority(for: type) > activityPriority(for: sneakPeek.type) {
            performActivityHandoff {
                toggleSneakPeek(status: false, type: sneakPeek.type)
            }
        }

        withAnimation(IslandMotion.content) {
            expandingView.show = status
            expandingView.type = type
            expandingView.value = value
            expandingView.browser = browser
        }
    }

    private var expandingViewTask: Task<Void, Never>?

    @Published var expandingView: ExpandedItem = .init() {
        didSet {
            if expandingView.show {
                expandingViewTask?.cancel()
                let duration: TimeInterval = (expandingView.type == .download ? 2 : 3)
                let currentType = expandingView.type
                expandingViewTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(duration))
                    guard let self = self, !Task.isCancelled else { return }
                    self.toggleExpandingView(status: false, type: currentType)
                }
            } else {
                expandingViewTask?.cancel()
                if !isHandingOffActivity {
                    presentNextActivityIfPossible()
                }
            }
        }
    }

    private func activityPriority(for type: SneakContentType) -> Int {
        switch type {
        case .battery: 5
        case .volume, .brightness, .backlight, .mic: 4
        case .download: 3
        case .focus, .connectivity: 2
        case .music: 1
        }
    }

    private func canPresent(type: SneakContentType) -> Bool {
        if expandingView.show,
           expandingView.type != type,
           activityPriority(for: expandingView.type) >= activityPriority(for: type) {
            return false
        }
        if sneakPeek.show,
           sneakPeek.type != type,
           activityPriority(for: sneakPeek.type) >= activityPriority(for: type) {
            return false
        }
        return true
    }

    private func enqueue(_ activity: PendingIslandActivity) {
        // Keep the newest update for a source, but retain unrelated work. A battery
        // change should not silently discard a pending download or media update.
        pendingActivities.removeAll { $0.type == activity.type }
        pendingActivities.append(activity)
        pendingActivities.sort { activityPriority(for: $0.type) > activityPriority(for: $1.type) }
    }

    private func performActivityHandoff(_ action: () -> Void) {
        isHandingOffActivity = true
        action()
        isHandingOffActivity = false
    }

    private func presentNextActivityIfPossible() {
        guard !sneakPeek.show, !expandingView.show, !pendingActivities.isEmpty else { return }
        let next = pendingActivities.removeFirst()
        switch next {
        case .sneakPeek(let type, let duration, let value, let icon):
            toggleSneakPeek(status: true, type: type, duration: duration, value: value, icon: icon)
        case .expanded(let type, let value, let browser):
            toggleExpandingView(status: true, type: type, value: value, browser: browser)
        }
    }
    
    func showEmpty() {
        currentView = .home
    }

    func dismissTransientActivitiesForLock() {
        sneakPeekTask?.cancel()
        expandingViewTask?.cancel()
        pendingActivities.removeAll()
        withAnimation(IslandMotion.content) {
            sneakPeek.show = false
            expandingView.show = false
        }
    }
}
