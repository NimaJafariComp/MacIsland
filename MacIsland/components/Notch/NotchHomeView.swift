//
//  NotchHomeView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-18.
//  Modified by Harsh Vardhan Goswami & Richard Kunkli & Mustafa Ramadan
//

import AppKit
import Combine
import Defaults
import SwiftUI

// MARK: - Music Player Components

struct MusicPlayerView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var musicManager = MusicManager.shared
    let albumArtNamespace: Namespace.ID
    let moduleHeight: CGFloat?

    private var contextualBorder: Color {
        guard musicManager.isPlaying, Defaults[.playerColorTinting] else {
            return Color.islandBorder
        }
        return Color(nsColor: musicManager.avgColor)
            .ensureMinimumBrightness(factor: 0.55)
            .opacity(0.45)
    }

    var body: some View {
        Group {
            if musicManager.isPlayerIdle && !musicManager.isPlaying {
                MusicIdleView()
            } else {
                HStack(spacing: 12) {
                    AlbumArtView(vm: vm, albumArtNamespace: albumArtNamespace)
                        .frame(
                            width: MusicPlayerImageSizes.size.opened.width,
                            height: MusicPlayerImageSizes.size.opened.height
                        )
                    MusicControlsView()
                        .drawingGroup()
                        .compositingGroup()
                }
                .padding(IslandStyle.modulePadding)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: moduleHeight,
            maxHeight: moduleHeight,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous)
                .fill(Color.islandModuleSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous)
                .stroke(contextualBorder, lineWidth: IslandStyle.hairlineWidth)
        }
        .overlay(alignment: .topTrailing) {
            if !musicManager.isPlayerIdle || musicManager.isPlaying {
                AudioOutputRoutePicker()
                    .padding(8)
            }
        }
    }
}

private struct MusicIdleView: View {
    @ObservedObject private var musicManager = MusicManager.shared

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.islandElevatedSurface)
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.islandSecondaryText)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing Playing")
                    .font(IslandTypography.title)
                    .foregroundStyle(Color.islandPrimaryText)
                Text(musicManager.mediaFallbackMessage ?? "Start audio in Music, Spotify, or another supported app.")
                    .font(IslandTypography.body)
                    .foregroundStyle(Color.islandSecondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }
}

struct AlbumArtView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if Defaults[.lightingEffect] {
                albumArtBackground
            }
            albumArtButton
        }
    }

    private var albumArtBackground: some View {
        Image(nsImage: musicManager.albumArt)
            .resizable()
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Defaults[.cornerRadiusScaling]
                        ? MusicPlayerImageSizes.cornerRadiusInset.opened
                        : MusicPlayerImageSizes.cornerRadiusInset.closed)
            )
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(x: 1.3, y: 1.4)
            .rotationEffect(.degrees(92))
            .blur(radius: 40)
            .opacity(musicManager.isPlaying ? 0.5 : 0)
    }

    private var albumArtButton: some View {
        ZStack {
            Button {
                musicManager.openMusicApp()
            } label: {
                ZStack(alignment:.bottomTrailing) {
                    albumArtImage
                    appIconOverlay
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(musicManager.isPlaying ? 1 : 0.85)
            
            albumArtDarkOverlay
        }
    }

    private var albumArtDarkOverlay: some View {
        Rectangle()
            .aspectRatio(1, contentMode: .fit)
            .foregroundColor(Color.islandHardwareSurface)
            .opacity(musicManager.isPlaying ? 0 : 0.8)
            .blur(radius: 50)
    }
                

    private var albumArtImage: some View {
        Image(nsImage: musicManager.albumArt)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Defaults[.cornerRadiusScaling]
                        ? MusicPlayerImageSizes.cornerRadiusInset.opened
                        : MusicPlayerImageSizes.cornerRadiusInset.closed)
            )
    }

    @ViewBuilder
    private var appIconOverlay: some View {
        if vm.notchState == .open && !musicManager.usingAppIconForArtwork {
            AppIcon(for: musicManager.bundleIdentifier ?? "com.apple.Music")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
                .offset(x: 10, y: 10)
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
        }
    }
}

struct MusicControlsView: View {
    @ObservedObject var musicManager = MusicManager.shared
        @EnvironmentObject var vm: BoringViewModel
        @ObservedObject var webcamManager = WebcamManager.shared
    @State private var sliderValue: Double = 0
    @State private var dragging: Bool = false
    @State private var lastDragged: Date = .distantPast
    @Default(.musicControlSlots) private var slotConfig
    @Default(.musicControlSlotLimit) private var slotLimit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            songInfo
            HStack(spacing: IslandStyle.compactControlSpacing) {
                musicSlider
                slotToolbar
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var songInfo: some View {
        GeometryReader { geo in
            songInfo(width: geo.size.width)
        }
        .frame(height: 34)
        .padding(.top, 4)
        .padding(.leading, 5)
        // The top-right output control overlays the player card. Preserve a
        // compact clearance so long titles never pass underneath it.
        .padding(.trailing, 34)
    }

    private func songInfo(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MarqueeText(
                $musicManager.songTitle, font: IslandTypography.title, nsFont: .headline, textColor: Color.islandPrimaryText,
                frameWidth: width)
            MarqueeText(
                $musicManager.artistName,
                font: .headline,
                nsFont: .headline,
                textColor: Defaults[.playerColorTinting]
                    ? Color(nsColor: musicManager.avgColor)
                        .ensureMinimumBrightness(factor: 0.6) : Color.islandSecondaryText,
                frameWidth: width
            )
            .fontWeight(.medium)
            if Defaults[.enableLyrics] {
                TimelineView(.animation(minimumInterval: 0.25)) { timeline in
                    let currentElapsed: Double = {
                        guard musicManager.isPlaying else { return musicManager.elapsedTime }
                        let delta = timeline.date.timeIntervalSince(musicManager.timestampDate)
                        let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
                        return min(max(progressed, 0), musicManager.songDuration)
                    }()
                    let line: String = {
                        if musicManager.isFetchingLyrics { return "Loading lyrics…" }
                        if !musicManager.syncedLyrics.isEmpty {
                            return musicManager.lyricLine(at: currentElapsed)
                        }
                        let trimmed = musicManager.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? "No lyrics found" : trimmed.replacingOccurrences(of: "\n", with: " ")
                    }()
                    let isPersian = line.unicodeScalars.contains { scalar in
                        let v = scalar.value
                        return v >= 0x0600 && v <= 0x06FF
                    }
                    MarqueeText(
                        .constant(line),
                        font: .subheadline,
                        nsFont: .subheadline,
                        textColor: musicManager.isFetchingLyrics ? Color.islandDisabledText : Color.islandSecondaryText,
                        frameWidth: width
                    )
                    .font(isPersian ? .custom("Vazirmatn-Regular", size: NSFont.preferredFont(forTextStyle: .subheadline).pointSize) : .subheadline)
                    .lineLimit(1)
                    .opacity(musicManager.isPlaying ? 1 : 0)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var musicSlider: some View {
        TimelineView(.animation(minimumInterval: musicManager.isPlaying && musicManager.playbackRate > 0 ? 0.1 : nil)) { timeline in
            MusicSliderView(
                sliderValue: $sliderValue,
                duration: $musicManager.songDuration,
                lastDragged: $lastDragged,
                color: musicManager.avgColor,
                dragging: $dragging,
                currentDate: timeline.date,
                timestampDate: musicManager.timestampDate,
                elapsedTime: musicManager.elapsedTime,
                playbackRate: musicManager.playbackRate,
                isPlaying: musicManager.isPlaying
            ) { newValue in
                MusicManager.shared.seek(to: newValue)
            }
            .padding(.top, 5)
            .frame(height: 36)
        }
    }

    private var slotToolbar: some View {
        let slots = activeSlots.filter { $0 != .none }
        return HStack(spacing: 4) {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                slotView(for: slot)
                    .frame(alignment: .center)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var activeSlots: [MusicControlButton] {
        let sanitizedLimit = min(
            max(slotLimit, MusicControlButton.minSlotCount),
            MusicControlButton.maxSlotCount
        )
        let padded = slotConfig.padded(to: sanitizedLimit, filler: .none)
        let result = Array(padded.prefix(sanitizedLimit))
        return result
    }

    @ViewBuilder
    private func slotView(for slot: MusicControlButton) -> some View {
        switch slot {
        case .shuffle:
            HoverButton(icon: "shuffle", iconColor: musicManager.isShuffled ? .islandCritical : .islandPrimaryText, scale: .medium, buttonSize: 28) {
                MusicManager.shared.toggleShuffle()
            }
        case .previous:
            HoverButton(icon: "backward.fill", scale: .medium, buttonSize: 28) {
                MusicManager.shared.previousTrack()
            }
        case .playPause:
            HoverButton(icon: musicManager.isPlaying ? "pause.fill" : "play.fill", scale: .large, buttonSize: 32) {
                MusicManager.shared.togglePlay()
            }
        case .next:
            HoverButton(icon: "forward.fill", scale: .medium, buttonSize: 28) {
                MusicManager.shared.nextTrack()
            }
        case .repeatMode:
            HoverButton(icon: repeatIcon, iconColor: repeatIconColor, scale: .medium, buttonSize: 28) {
                MusicManager.shared.toggleRepeat()
            }
        case .volume:
            VolumeControlView()
        case .favorite:
            FavoriteControlButton()
        case .goBackward:
            HoverButton(icon: "gobackward.15", scale: .medium, buttonSize: 28) {
                MusicManager.shared.skip(seconds: -15)
            }
        case .goForward:
            HoverButton(icon: "goforward.15", scale: .medium, buttonSize: 28) {
                MusicManager.shared.skip(seconds: 15)
            }
        case .none:
            Color.clear.frame(
                width: IslandStyle.minimumHitTarget,
                height: IslandStyle.minimumHitTarget
            )
        }
    }

    private var repeatIcon: String {
        switch musicManager.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    private var repeatIconColor: Color {
        switch musicManager.repeatMode {
        case .off:
            return .islandPrimaryText
        case .all, .one:
            return .islandCritical
        }
    }
}

/// SwiftUI owns the menu state; Core Audio owns the system route list and the
/// default-output change. This is a public macOS route picker, not a private
/// Control Center imitation.
private struct AudioOutputRoutePicker: View {
    @ObservedObject private var volumeManager = VolumeManager.shared
    @State private var isPresented = false

    var body: some View {
        Button {
            volumeManager.refreshOutputRoutes()
            isPresented.toggle()
        } label: {
            Image(systemName: "speaker.wave.2.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.islandPrimaryText)
                .frame(width: 26, height: 26)
                .background(Color.islandElevatedSurface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Choose audio output")
        .accessibilityLabel("Choose audio output")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio Output")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                if volumeManager.outputRoutes.isEmpty {
                    Text("No audio outputs available")
                        .foregroundStyle(.secondary)
                        .padding(12)
                } else {
                    ForEach(volumeManager.outputRoutes) { route in
                        Button {
                            if volumeManager.selectOutputRoute(route) {
                                isPresented = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: route.isAirPlay ? "airplayaudio" : "speaker.wave.2")
                                    .frame(width: 16)
                                Text(route.name)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                if route.id == volumeManager.currentOutputRouteID {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(route.id == volumeManager.currentOutputRouteID)
                    }
                }

                Divider()
                Button("Sound Settings…") {
                    guard let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") else { return }
                    NSWorkspace.shared.open(url)
                    isPresented = false
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(width: 230)
        }
        .onAppear { volumeManager.refreshOutputRoutes() }
    }
}

struct FavoriteControlButton: View {
    @ObservedObject var musicManager = MusicManager.shared

    var body: some View {
        HoverButton(icon: iconName, iconColor: iconColor, scale: .medium) {
            MusicManager.shared.toggleFavoriteTrack()
        }
        .disabled(!musicManager.canFavoriteTrack)
    }

    private var iconName: String {
        musicManager.isFavoriteTrack ? "heart.fill" : "heart"
    }

    private var iconColor: Color {
        guard musicManager.canFavoriteTrack else { return .islandDisabledText }
        return musicManager.isFavoriteTrack ? .islandCritical : .islandPrimaryText
    }
}

private extension Array where Element == MusicControlButton {
    func padded(to length: Int, filler: MusicControlButton) -> [MusicControlButton] {
        if count >= length { return self }
        return self + Array(repeating: filler, count: length - count)
    }
}

// MARK: - Volume Control View

struct VolumeControlView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @State private var volumeSliderValue: Double = 0.5
    @State private var dragging: Bool = false
    @State private var showVolumeSlider: Bool = false
    @State private var lastVolumeUpdateTime: Date = Date.distantPast
    private let volumeUpdateThrottle: TimeInterval = 0.1
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                if musicManager.volumeControlSupported {
                    withAnimation(IslandMotion.interaction) {
                        showVolumeSlider.toggle()
                    }
                }
            }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(musicManager.volumeControlSupported ? Color.islandPrimaryText : Color.islandDisabledText)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!musicManager.volumeControlSupported)
            .frame(width: 24)

            if showVolumeSlider && musicManager.volumeControlSupported {
                CustomSlider(
                    value: $volumeSliderValue,
                    range: 0.0...1.0,
                    color: .islandPrimaryText,
                    dragging: $dragging,
                    lastDragged: .constant(Date.distantPast),
                    onValueChange: { newValue in
                        MusicManager.shared.setVolume(to: newValue)
                    },
                    onDragChange: { newValue in
                        let now = Date()
                        if now.timeIntervalSince(lastVolumeUpdateTime) > volumeUpdateThrottle {
                            MusicManager.shared.setVolume(to: newValue)
                            lastVolumeUpdateTime = now
                        }
                    }
                )
                .frame(width: 48, height: 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .clipped()
        .onReceive(musicManager.$volume) { volume in
            if !dragging {
                volumeSliderValue = volume
            }
        }
        .onReceive(musicManager.$volumeControlSupported) { supported in
            if !supported {
                withAnimation(IslandMotion.interaction) {
                    showVolumeSlider = false
                }
            }
        }
        .onChange(of: showVolumeSlider) { _, isShowing in
            if isShowing {
                // Sync volume from app when slider appears
                Task {
                    await MusicManager.shared.syncVolumeFromActiveApp()
                }
            }
        }
        .onDisappear {
            // volumeUpdateTask?.cancel() // No longer needed
        }
    }
    
    
    private var volumeIcon: String {
        if !musicManager.volumeControlSupported {
            return "speaker.slash"
        } else if volumeSliderValue == 0 {
            return "speaker.slash.fill"
        } else if volumeSliderValue < 0.33 {
            return "speaker.1.fill"
        } else if volumeSliderValue < 0.66 {
            return "speaker.2.fill"
        } else {
            return "speaker.3.fill"
        }
    }
}

// MARK: - Main View

struct NotchHomeView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject private var uiAudit = UIAuditController.shared
    let albumArtNamespace: Namespace.ID
    let availableSize: CGSize

    var body: some View {
        Group {
            if !coordinator.firstLaunch {
                mainContent
            }
        }
        // simplified: use a straightforward opacity transition
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var shouldShowCamera: Bool {
        (Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded)
            || (UIAuditMode.isEnabled && uiAudit.state == .camera)
    }

    private var layoutBudget: HomeLayoutBudget {
        HomeLayoutBudget(
            availableSize: availableSize,
            wantsCalendar: Defaults[.showCalendar],
            wantsCamera: shouldShowCamera,
            showsWeather: Defaults[.weatherEnabled] || (UIAuditMode.isEnabled && uiAudit.state == .error)
        )
    }

    private var mainContent: some View {
        let budget = layoutBudget

        return ZStack(alignment: .top) {
            HomeAmbientBackdrop()

            VStack(spacing: IslandStyle.homeSectionSpacing) {
                if Defaults[.weatherEnabled] || (UIAuditMode.isEnabled && uiAudit.state == .error) {
                    HomeWeatherModule()
                        .frame(height: IslandStyle.homeWeatherHeight)
                }

                HStack(alignment: .top, spacing: IslandStyle.homeModuleSpacing) {
                    MusicPlayerView(
                        albumArtNamespace: albumArtNamespace,
                        moduleHeight: budget.moduleHeight
                    )
                        .frame(
                            width: budget.mediaWidth,
                            height: budget.moduleHeight,
                            alignment: .leading
                        )

                    if let calendarWidth = budget.calendarWidth {
                        HomeCalendarCard(moduleHeight: budget.moduleHeight)
                            .frame(width: calendarWidth, height: budget.moduleHeight)
                            .onHover { isHovering in
                                vm.isHoveringCalendar = isHovering
                            }
                            .environmentObject(vm)
                            .transition(.opacity)
                    }

                    if let cameraSize = budget.cameraSize {
                        CameraPreviewView(webcamManager: webcamManager)
                            .frame(width: cameraSize.width, height: cameraSize.height)
                            .opacity(vm.notchState == .closed ? 0 : 1)
                            .blur(radius: vm.notchState == .closed ? 20 : 0)
                            .animation(IslandMotion.content, value: shouldShowCamera)
                            .accessibilityLabel("Camera mirror preview")
                            .accessibilityValue(webcamManager.isSessionRunning ? "Live" : (webcamManager.statusMessage ?? "Unavailable"))
                    }
                }
                .frame(height: budget.moduleHeight, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, IslandStyle.homeHorizontalInset)
        .padding(.top, IslandStyle.homeTopInset)
        .padding(.bottom, IslandStyle.homeBottomInset)
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
        .blur(radius: vm.notchState == .closed ? 30 : 0)
    }
}

/// MacIsland's signature treatment: the playing artwork casts a restrained
/// pool of color through the lower surface while the camera bridge stays
/// hardware black. This is intentionally static under Reduce Motion.
private struct HomeAmbientBackdrop: View {
    @ObservedObject private var musicManager = MusicManager.shared

    private var tint: Color {
        Color(nsColor: musicManager.avgColor)
            .ensureMinimumBrightness(factor: 0.55)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        .clear,
                        tint.opacity(musicManager.isPlaying ? Color.islandAmbientGlowOpacity * 0.45 : 0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(musicManager.isPlaying ? Color.islandAmbientGlowOpacity : 0),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(proxy.size.width * 0.42, 1)
                        )
                    )
                    .frame(width: proxy.size.width * 0.78, height: 76)
                    .offset(x: -proxy.size.width * 0.08, y: 24)
                    .blur(radius: 18)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct HomeWeatherModule: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @ObservedObject private var uiAudit = UIAuditController.shared

    var body: some View {
        Button(action: openWeather) {
            weatherContent
        }
        .buttonStyle(.plain)
        .help("Open Weather")
        .accessibilityLabel("Open Weather")
        .accessibilityHint("Opens the Weather app")
        .contentShape(Capsule())
    }

    @ViewBuilder
    private var weatherContent: some View {
        Group {
            if UIAuditMode.isEnabled && uiAudit.state == .error {
                Label("Audit error: weather unavailable", systemImage: "exclamationmark.triangle")
            } else {
                switch coordinator.weatherStatus {
            case .ready:
                if let snapshot = coordinator.weatherSnapshot {
                    Label(
                        "\(snapshot.location) · \(snapshot.formattedTemperature(in: Defaults[.weatherTemperatureUnit])) · \(weatherDescription(for: snapshot.weatherCode))",
                        systemImage: weatherSymbol(for: snapshot.weatherCode)
                    )
                }
            case .loading:
                if let snapshot = coordinator.weatherSnapshot {
                    Label(
                        "\(snapshot.location) · \(snapshot.formattedTemperature(in: Defaults[.weatherTemperatureUnit])) · \(weatherDescription(for: snapshot.weatherCode))",
                        systemImage: weatherSymbol(for: snapshot.weatherCode)
                    )
                } else {
                    Label("Weather will appear here", systemImage: "cloud.sun")
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
            case .idle:
                Label("Choose a city in Settings", systemImage: "cloud.sun")
            }
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.islandSecondaryText)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(height: IslandStyle.homeWeatherHeight)
        .background(
            Color.islandModuleSurface,
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(Color.islandModuleBorder, lineWidth: IslandStyle.hairlineWidth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openWeather() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Weather.app"))
    }

    private func weatherSymbol(for code: Int) -> String {
        switch code {
        case 0: "sun.max.fill"
        case 1...3: "cloud.sun.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...67, 80...82: "cloud.rain.fill"
        case 71...77, 85...86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    private func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: "Clear"
        case 1...3: "Partly cloudy"
        case 45, 48: "Fog"
        case 51...67, 80...82: "Rain"
        case 71...77, 85...86: "Snow"
        case 95...99: "Thunderstorm"
        default: "Cloudy"
        }
    }
}

struct MusicSliderView: View {
    @Binding var sliderValue: Double
    @Binding var duration: Double
    @Binding var lastDragged: Date
    var color: NSColor
    @Binding var dragging: Bool
    let currentDate: Date
    let timestampDate: Date
    let elapsedTime: Double
    let playbackRate: Double
    let isPlaying: Bool
    var onValueChange: (Double) -> Void


    var body: some View {
        VStack {
            CustomSlider(
                value: $sliderValue,
                range: 0...duration,
                color: Defaults[.sliderColor] == SliderColorEnum.albumArt
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.8)
                    : Defaults[.sliderColor] == SliderColorEnum.accent ? .islandFocus : .islandPrimaryText,
                dragging: $dragging,
                lastDragged: $lastDragged,
                onValueChange: onValueChange
            )
            .frame(height: 10, alignment: .center)

            HStack {
                Text(timeString(from: sliderValue))
                Spacer()
                Text(timeString(from: duration))
            }
            .fontWeight(.medium)
            .foregroundColor(
                Defaults[.playerColorTinting]
                    ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.6) : Color.islandSecondaryText
            )
            .font(.caption)
        }
        .onChange(of: currentDate) {
           guard !dragging, timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
            sliderValue = MusicManager.shared.estimatedPlaybackPosition(at: currentDate)
        }
    }

    func timeString(from seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var color: Color = .islandPrimaryText
    @Binding var dragging: Bool
    @Binding var lastDragged: Date
    var onValueChange: ((Double) -> Void)?
    var onDragChange: ((Double) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = CGFloat(dragging ? 9 : 5)
            let rangeSpan = range.upperBound - range.lowerBound

            let progress = rangeSpan == .zero ? 0 : (value - range.lowerBound) / rangeSpan
            let filledTrackWidth = min(max(progress, 0), 1) * width

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.islandTrack)
                    .frame(height: height)

                Rectangle()
                    .fill(color)
                    .frame(width: filledTrackWidth, height: height)
            }
            .cornerRadius(height / 2)
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation(IslandMotion.interaction) {
                            dragging = true
                        }
                        let newValue = range.lowerBound + Double(gesture.location.x / width) * rangeSpan
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onDragChange?(value)
                    }
                    .onEnded { _ in
                        onValueChange?(value)
                        dragging = false
                        lastDragged = Date()
                    }
            )
            .animation(IslandMotion.interaction, value: dragging)
        }
    }
}
