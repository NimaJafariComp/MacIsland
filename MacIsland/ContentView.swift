//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import Defaults
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect

enum IslandScene: Equatable {
    case onboarding
    case battery
    case systemHUD
    case timer
    case media
    case face
    case home
    case shelf
    case collapsed
}

struct IslandSceneInput {
    let isOnboarding: Bool
    let isOpen: Bool
    let currentView: NotchViews
    let isBatteryActivityVisible: Bool
    let isSystemHUDVisible: Bool
    let isTimerVisible: Bool
    let isTimerCompleted: Bool
    let isMediaVisible: Bool
    let isIdleFaceVisible: Bool
    let isScreenLocked: Bool

    init(
        isOnboarding: Bool,
        isOpen: Bool,
        currentView: NotchViews,
        isBatteryActivityVisible: Bool,
        isSystemHUDVisible: Bool,
        isTimerVisible: Bool,
        isTimerCompleted: Bool,
        isMediaVisible: Bool,
        isIdleFaceVisible: Bool,
        isScreenLocked: Bool = false
    ) {
        self.isOnboarding = isOnboarding
        self.isOpen = isOpen
        self.currentView = currentView
        self.isBatteryActivityVisible = isBatteryActivityVisible
        self.isSystemHUDVisible = isSystemHUDVisible
        self.isTimerVisible = isTimerVisible
        self.isTimerCompleted = isTimerCompleted
        self.isMediaVisible = isMediaVisible
        self.isIdleFaceVisible = isIdleFaceVisible
        self.isScreenLocked = isScreenLocked
    }
}

enum IslandSceneResolver {
    /// User-opened content wins. Closed live-activity priority is battery,
    /// completed timer, system HUD, active timer, media, then idle face.
    /// A completed timer holds its acknowledgement control through transient HUDs;
    /// battery remains first because it can convey a critical system condition.
    static func resolve(_ input: IslandSceneInput) -> IslandScene {
        if input.isScreenLocked { return .collapsed }
        if input.isOnboarding { return .onboarding }
        if input.isOpen {
            return input.currentView == .shelf ? .shelf : .home
        }
        if input.isBatteryActivityVisible { return .battery }
        if input.isTimerCompleted { return .timer }
        if input.isSystemHUDVisible { return .systemHUD }
        if input.isTimerVisible { return .timer }
        if input.isMediaVisible { return .media }
        if input.isIdleFaceVisible { return .face }
        return .collapsed
    }
}

@MainActor
struct ContentView: View {
    @ObservedObject private var uiAudit = UIAuditController.shared
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject private var notesStore = AppleNotesStore.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State private var gestureProgress: CGFloat = .zero

    @State private var haptics: Bool = false
    /// The compact endpoint remains fixed for a complete open/close morph.
    /// In particular, media must not change from its winged compact geometry
    /// to the plain hardware-notch geometry when Home content is staged in.
    @State private var retainedClosedScene: IslandScene = .collapsed

    @Namespace var albumArtNamespace

    @Default(.useMusicVisualizer) var useMusicVisualizer

    @Default(.showNotHumanFace) var showNotHumanFace

    // Core island motion stays in one contract; this alias keeps call sites clear.
    private var interactionSpring: Animation { IslandMotion.interaction }

    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10

    private var topCornerRadius: CGFloat {
        let openRadius = Defaults[.cornerRadiusScaling]
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
        return cornerRadiusInsets.closed.top
            + (openRadius - cornerRadiusInsets.closed.top) * vm.islandMorphProgress
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: cornerRadiusInsets.closed.bottom
                + ((Defaults[.cornerRadiusScaling]
                    ? cornerRadiusInsets.opened.bottom
                    : cornerRadiusInsets.closed.bottom)
                    - cornerRadiusInsets.closed.bottom) * vm.islandMorphProgress
        )
    }

    private func computedChinWidth(for scene: IslandScene) -> CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        switch scene {
        case .battery:
            chinWidth = 640
        case .timer:
            chinWidth = ClosedTimerActivityGeometry(
                physicalBridgeWidth: chinWidth
            ).contentWidth
        case .media, .face:
            let media = ClosedMediaActivityGeometry(
                physicalBridgeWidth: vm.closedNotchSize.width,
                closedHeight: vm.effectiveClosedNotchHeight
            )
            chinWidth = media.totalWidth
        default:
            break
        }

        return chinWidth
    }

    private func closedActivityHeight(for scene: IslandScene) -> CGFloat {
        guard scene == .timer else { return vm.effectiveClosedNotchHeight }
        return vm.effectiveClosedNotchHeight
            + ClosedTimerActivityGeometry.controlHeight
            + ClosedTimerActivityGeometry.bottomInset
    }

    /// The outer proposal must follow the same compact-to-expanded height as
    /// `IslandSurface`. Timer controls intentionally sit below the hardware
    /// bridge, so constraining this to `vm.notchSize.height` clips them.
    private var renderedIslandHeight: CGFloat {
        let compactHeight = closedActivityHeight(for: shellClosedScene)
        let expandedHeight = vm.currentOpenIslandSize.height
        return compactHeight + (expandedHeight - compactHeight) * vm.islandMorphProgress
    }

    private var shellClosedScene: IslandScene {
        // @State is deliberately initialized to the neutral geometry. A live
        // media session can already exist before SwiftUI delivers the first
        // onAppear capture, though; use that resolved source for the first
        // frame rather than briefly rendering an empty Island.
        if retainedClosedScene == .collapsed, compactIslandScene != .collapsed {
            return compactIslandScene
        }
        return retainedClosedScene
    }

    /// The compact source stays independently resolved while expanded content
    /// is overlaid. This prevents an opening Home page from replacing a media
    /// live activity before its shared artwork can complete the morph.
    private var compactIslandScene: IslandScene {
        IslandSceneResolver.resolve(
            IslandSceneInput(
                isOnboarding: coordinator.helloAnimationRunning,
                isOpen: false,
                currentView: coordinator.currentView,
                isBatteryActivityVisible: coordinator.expandingView.type == .battery
                    && coordinator.expandingView.show
                    && Defaults[.showPowerStatusNotifications],
                isSystemHUDVisible: coordinator.sneakPeek.show
                    && (coordinator.sneakPeek.type.isSystemState
                        || (Defaults[.inlineHUD]
                            && coordinator.sneakPeek.type != .music
                            && coordinator.sneakPeek.type != .battery)),
                isTimerVisible: coordinator.timerStatus.isVisible && !vm.hideOnClosed,
                isTimerCompleted: coordinator.timerStatus == .completed && !vm.hideOnClosed,
                isMediaVisible: (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
                    && (musicManager.isPlaying || !musicManager.isPlayerIdle)
                    && coordinator.musicLiveActivityEnabled
                    && !vm.hideOnClosed,
                isIdleFaceVisible: !coordinator.expandingView.show
                    && !musicManager.isPlaying
                    && musicManager.isPlayerIdle
                    && Defaults[.showNotHumanFace]
                    && !vm.hideOnClosed,
                isScreenLocked: vm.isScreenLocked
            )
        )
    }

    var body: some View {
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                let mainLayout = IslandSurface(
                    morphProgress: vm.islandMorphProgress,
                    isHovering: isHovering || (UIAuditMode.isEnabled && uiAudit.state == .hover),
                    usesFlushClosedGeometry: shellClosedScene == .collapsed,
                    openSize: vm.currentOpenIslandSize,
                    closedSize: CGSize(
                        width: (shellClosedScene == .media || shellClosedScene == .timer)
                            ? computedChinWidth(for: shellClosedScene)
                            : vm.closedSurfaceSize.width,
                        height: closedActivityHeight(for: shellClosedScene)
                    ),
                    closedContentWidth: (shellClosedScene == .media || shellClosedScene == .timer)
                        ? computedChinWidth(for: shellClosedScene)
                        : nil,
                    closedHeight: closedActivityHeight(for: shellClosedScene),
                    cornerRadiusScaling: Defaults[.cornerRadiusScaling],
                    shape: currentNotchShape,
                    topCornerRadius: topCornerRadius
                ) {
                    NotchLayout()
                }

                let hoverHorizontalInset = vm.usesClosedHoverTarget
                    ? max(0, (vm.hoverHitSize.width - vm.closedSurfaceSize.width) / 2)
                    : 0
                let hoverBottomInset = vm.usesClosedHoverTarget
                    ? max(0, vm.hoverHitSize.height - vm.closedSurfaceSize.height)
                    : 0
                
                mainLayout
                    // Never animate from an unconstrained (`nil`) proposal.
                    // Both states need concrete dimensions for SwiftUI to
                    // interpolate the outer Island silhouette rather than
                    // only fading the page content.
                    .frame(height: renderedIslandHeight)
                    // The clear target implements NotchMetrics.hoverHitFrame
                    // without enlarging or recoloring the physical bridge.
                    .padding(.horizontal, hoverHorizontalInset)
                    .padding(.bottom, hoverBottomInset)
                    // Open/close is a single physical-surface transition.
                    // Page sizing deliberately has no SwiftUI animation owner;
                    // both layers share the same model-owned transition.
                    .animation(IslandMotion.islandOpenClose, value: vm.notchState)
                    .animation(IslandMotion.islandOpenClose, value: vm.notchSize)
                    .animation(IslandMotion.islandOpenClose, value: vm.islandMorphProgress)
                    .conditionalModifier(true) { view in
                        return view
                            // AppKit owns panel-frame motion. Keeping a second
                            // size animation here causes the SwiftUI surface to
                            // lag behind the panel and briefly expose the host.
                            .animation(IslandMotion.interaction, value: gestureProgress)
                    }
                    .contentShape(Rectangle())
                    // Keep the island discoverable as one container without
                    // flattening the tab controls into its identifier.
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("macisland.island")
                    .accessibilityLabel(vm.notchState == .closed ? "Open MacIsland" : "MacIsland island")
                    .accessibilityAddTraits(vm.notchState == .closed ? .isButton : [])
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    // Opening is a closed-island affordance. Keeping this
                    // parent gesture active while open steals taps from the
                    // header tabs and other child controls.
                    .conditionalModifier(vm.notchState == .closed) { view in
                        view.onTapGesture {
                            doOpen()
                        }
                    }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures]) { view in
                        view.panGesture(direction: .up, capturesScrollWheel: false) { translation, phase in
                            handleUpGesture(translation: translation, phase: phase)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                        if vm.notchState == .open && !isHovering && !vm.isBatteryPopoverActive {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.vm.notchState == .open && !self.isHovering && !self.vm.isBatteryPopoverActive && !self.vm.isMirrorSessionPinned && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        if newState == .closed && isHovering {
                            withAnimation(IslandMotion.interaction) {
                                isHovering = false
                            }
                        }
                    }
                    .onChange(of: vm.isBatteryPopoverActive) {
                        if !vm.isBatteryPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if !self.vm.isBatteryPopoverActive && !self.isHovering && self.vm.notchState == .open && !self.vm.isMirrorSessionPinned && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.isMirrorSessionPinned) { _, isPinned in
                        // Once the last Mirror activity ends, return to the
                        // ordinary hover-dismiss contract. Do not close while
                        // the pointer is still inside the island.
                        guard !isPinned, !isHovering, vm.notchState == .open,
                              !vm.isBatteryPopoverActive,
                              !SharingStateManager.shared.preventNotchClose
                        else { return }
                        hoverTask?.cancel()
                        hoverTask = Task {
                            try? await Task.sleep(for: .milliseconds(100))
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                guard !self.vm.isMirrorSessionPinned,
                                      !self.isHovering,
                                      self.vm.notchState == .open,
                                      !self.vm.isBatteryPopoverActive,
                                      !SharingStateManager.shared.preventNotchClose
                                else { return }
                                self.vm.close()
                            }
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            DispatchQueue.main.async {
                                SettingsWindowController.shared.showWindow()
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                        //                    Button("Edit") { // Doesnt work....
                        //                        let dn = DynamicNotch(content: EditPanelView())
                        //                        dn.toggle()
                        //                    }
                        //                    .keyboardShortcut("E", modifiers: .command)
                    }
                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.islandHitTarget)
                        .frame(width: computedChinWidth(for: shellClosedScene), height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: vm.panelSize.width, maxHeight: vm.panelSize.height, alignment: .top)
        .compositingGroup()
        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(IslandMotion.interaction, value: gestureProgress)
        .background(dragDetector)
        .overlay(alignment: .top) {
            if vm.anyDropZoneTargeting {
                Rectangle()
                    .fill(Color.islandFocus)
                    .frame(height: 1)
                    .shadow(color: Color.islandFocus.opacity(0.7), radius: 3)
                    .accessibilityLabel("Drop target active")
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .allowsHitTesting(!vm.isScreenLocked)
        .environmentObject(vm)
        // Warm the Notes cache off-screen. Opening the Quick Notes tab should
        // present cached content immediately rather than a visible loader.
        .task(priority: .utility) {
            await notesStore.preload()
        }
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    coordinator.currentView = .shelf
                    doOpen()
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                if !SharingStateManager.shared.preventNotchClose {
                    vm.close()
                }
            }
        }
        .onDisappear {
            hoverTask?.cancel()
            hoverTask = nil
            anyDropDebounceTask?.cancel()
            anyDropDebounceTask = nil
        }
        .modifier(
            ClosedSceneRetention(
                retainedScene: $retainedClosedScene,
                isSettledCompact: vm.presentationPhase == .compact,
                scene: compactIslandScene
            )
        )
        .onChange(of: coordinator.currentView) { _, _ in
            NotificationCenter.default.post(name: .islandPanelSizeDidChange, object: vm)
        }
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        ZStack(alignment: .top) {
            compactActivityLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .opacity(vm.compactContentOpacity)
                .scaleEffect(0.985 + vm.compactContentOpacity * 0.015, anchor: .top)
                .allowsHitTesting(vm.presentationPhase == .compact)
                .zIndex(0)

            if vm.isExpandedContentMounted {
                expandedPageLayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(vm.expandedContentOpacity)
                    .scaleEffect(0.985 + vm.expandedContentOpacity * 0.015, anchor: .top)
                    .offset(y: (1 - vm.expandedContentOpacity) * 8)
                    .allowsHitTesting(vm.notchState == .open)
                    .zIndex(1)
            }
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    @ViewBuilder
    private var compactActivityLayer: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch compactIslandScene {
                case .onboarding:
                    Spacer()
                    HelloAnimation(onFinish: {
                        vm.closeHello()
                    }).frame(
                        width: getClosedNotchSize().width,
                        height: 80
                    )
                    .padding(.top, 40)
                    Spacer()
                case .battery:
                    compactPresentation { BatteryLiveActivity() }
                case .systemHUD:
                    if coordinator.sneakPeek.type.isSystemState {
                        compactPresentation { SystemStateLiveActivity(
                            type: coordinator.sneakPeek.type,
                            value: coordinator.sneakPeek.value
                        ) }
                    } else {
                        compactPresentation {
                            InlineHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon, hoverAnimation: $isHovering, gestureProgress: $gestureProgress)
                                .transition(.opacity)
                        }
                    }
                case .timer:
                    compactPresentation { TimerLiveActivity() }
                case .media:
                    compactPresentation { MusicLiveActivity().frame(alignment: .center) }
                case .face:
                    compactPresentation { BoringFaceAnimation() }
                case .home, .shelf:
                    BoringHeader()
                        .frame(height: max(24, vm.effectiveClosedNotchHeight))
                        .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
                case .collapsed:
                    Rectangle()
                        .fill(.clear)
                        .frame(
                            width: vm.closedSurfaceSize.width,
                            height: vm.effectiveClosedNotchHeight
                        )
            }

            compactSneakPeek
                .zIndex(2)
        }
        .conditionalModifier((coordinator.sneakPeek.show && (coordinator.sneakPeek.type == .music) && vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard) || (coordinator.sneakPeek.show && (coordinator.sneakPeek.type != .music) && (vm.notchState == .closed))) { view in
            view.fixedSize()
        }
    }

    @ViewBuilder
    private var compactSneakPeek: some View {
        if coordinator.sneakPeek.show {
            if coordinator.sneakPeek.type.requiresHUDReplacement && !Defaults[.inlineHUD] && vm.notchState == .closed && !vm.isScreenLocked {
                SystemEventIndicatorModifier(
                    eventType: $coordinator.sneakPeek.type,
                    value: $coordinator.sneakPeek.value,
                    icon: $coordinator.sneakPeek.icon,
                    sendEventBack: { newValue in
                        switch coordinator.sneakPeek.type {
                        case .volume:
                            VolumeManager.shared.setAbsolute(Float32(newValue))
                        case .brightness:
                            BrightnessManager.shared.setAbsolute(value: Float32(newValue))
                        default:
                            break
                        }
                    }
                )
                .padding(.bottom, 10)
                .padding(.leading, 4)
                .padding(.trailing, 8)
            } else if coordinator.sneakPeek.type == .music,
                      vm.notchState == .closed,
                      !vm.hideOnClosed,
                      Defaults[.sneakPeekStyles] == .standard {
                HStack(alignment: .center) {
                    Image(systemName: "music.note")
                    GeometryReader { geo in
                        MarqueeText(
                            .constant(musicManager.songTitle + " - " + musicManager.artistName),
                            textColor: Defaults[.playerColorTinting]
                                ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
                                : Color.islandSecondaryText,
                            minDuration: 1,
                            frameWidth: geo.size.width
                        )
                    }
                }
                .foregroundStyle(Color.islandSecondaryText)
                .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private var expandedPageLayer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The header belongs to the expanded hierarchy. Keeping it here
            // preserves the normal tabs and system actions while the compact
            // source remains mounted beneath this layer during the morph.
            BoringHeader()
                .frame(height: max(24, vm.effectiveClosedNotchHeight))

            expandedPageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, IslandStyle.headerContentSpacing)
        }
        .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
    }

    @ViewBuilder
    private var expandedPageContent: some View {
        Group {
            switch coordinator.currentView {
            case .home:
                NotchHomeView(
                    albumArtNamespace: albumArtNamespace,
                    availableSize: IslandStyle.expandedPageSize(
                        openIslandSize: vm.openIslandSize,
                        headerHeight: vm.effectiveClosedNotchHeight,
                        surfaceHorizontalInset: topCornerRadius + IslandStyle.openSurfacePadding
                    )
                )
            case .mirror:
                MirrorView()
            case .calendar:
                CalendarView()
            case .shelf:
                ShelfView()
            case .clipboard:
                ClipboardHistoryView()
            case .notes:
                QuickNotesView()
            }
        }
    }

    @ViewBuilder
    private func compactPresentation<Presentation: View>(
        @ViewBuilder content: () -> Presentation
    ) -> some View {
        content()
    }

    @ViewBuilder
    func BatteryLiveActivity() -> some View {
        HStack(spacing: 0) {
            Text(batteryModel.statusText)
                .font(.subheadline)
                .foregroundStyle(Color.islandPrimaryText)

            Rectangle()
                .fill(Color.islandHardwareSurface)
                .frame(width: vm.closedNotchSize.width + 10)

            BoringBatteryView(
                batteryWidth: 30,
                isCharging: batteryModel.isCharging,
                isInLowPowerMode: batteryModel.isInLowPowerMode,
                isPluggedIn: batteryModel.isPluggedIn,
                levelBattery: batteryModel.levelBattery,
                isForNotification: true
            )
            .frame(width: 76, alignment: .trailing)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(batteryModel.statusText)
    }

    @ViewBuilder
    func BoringFaceAnimation() -> some View {
        HStack {
            HStack {
                Rectangle()
                    .fill(.clear)
                    .frame(
                        width: max(0, vm.effectiveClosedNotchHeight - 12),
                        height: max(0, vm.effectiveClosedNotchHeight - 12)
                    )
                Rectangle()
                    .fill(Color.islandHardwareSurface)
                    .frame(width: vm.closedNotchSize.width - 20)
                MinimalFaceFeatures()
            }
        }.frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
        let layout = ClosedMediaActivityGeometry(
            physicalBridgeWidth: vm.closedNotchSize.width,
            closedHeight: vm.effectiveClosedNotchHeight
        )

        HStack(spacing: 0) {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .clipped()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed)
                )
                .matchedGeometryEffect(
                    id: "albumArt",
                    in: albumArtNamespace,
                    // Source ownership follows the visible layer handoff,
                    // rather than waiting for the shell's later settled phase.
                    // Otherwise expanded artwork remains hidden for most of
                    // every hover-open animation.
                    isSource: vm.compactContentOpacity > 0.5
                )
                .frame(
                    width: layout.wingWidth,
                    height: layout.wingWidth
                )

            Rectangle()
                .fill(Color.islandHardwareSurface)
                .overlay(
                    HStack(alignment: .top) {
                        if coordinator.expandingView.show
                            && coordinator.expandingView.type == .music
                        {
                            MarqueeText(
                                .constant(musicManager.songTitle),
                                textColor: Defaults[.coloredSpectrogram]
                                    ? Color(nsColor: musicManager.avgColor) : Color.islandSecondaryText,
                                minDuration: 0.4,
                                frameWidth: 100
                            )
                            .opacity(
                                (coordinator.expandingView.show
                                    && Defaults[.sneakPeekStyles] == .inline)
                                    ? 1 : 0
                            )
                            Spacer(minLength: vm.closedNotchSize.width)
                            // Song Artist
                            Text(musicManager.artistName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(
                                    Defaults[.coloredSpectrogram]
                                        ? Color(nsColor: musicManager.avgColor)
                                        : Color.islandSecondaryText
                                )
                                .opacity(
                                    (coordinator.expandingView.show
                                        && coordinator.expandingView.type == .music
                                        && Defaults[.sneakPeekStyles] == .inline)
                                        ? 1 : 0
                                )
                        }
                    }
                )
                .frame(
                    width: (coordinator.expandingView.show
                        && coordinator.expandingView.type == .music
                        && Defaults[.sneakPeekStyles] == .inline)
                        ? 380
                        : layout.bridgeWidth
                )

            HStack {
                if useMusicVisualizer {
                    Rectangle()
                        .fill(
                            Defaults[.coloredSpectrogram]
                                ? Color(nsColor: musicManager.avgColor).gradient
                                : Color.islandSecondaryText.gradient
                        )
                        .frame(width: 50, alignment: .center)
                        .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                        .mask {
                            AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                                .frame(width: 16, height: 12)
                        }
                } else {
                    if musicManager.isPlaying {
                        LottieAnimationContainer()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(
                width: max(
                    0,
                    layout.wingWidth + gestureProgress / 2
                ),
                height: max(
                    0,
                    layout.wingWidth
                ),
                alignment: .center
            )
        }
        .frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func TimerLiveActivity() -> some View {
        VStack(spacing: 0) {
            // Keep physical camera housing visually silent. Activity controls begin below it.
            Color.clear
                .frame(height: vm.effectiveClosedNotchHeight)

            HStack(spacing: 8) {
                Image(systemName: coordinator.timerStatus == .completed ? "bell.fill" : "timer")
                    .foregroundStyle(coordinator.timerStatus == .completed ? Color.islandFocus : Color.islandPrimaryText)

                Text(timerText)
                    .font(IslandTypography.numericControl)

                if coordinator.timerStatus == .completed {
                    Button("Done") { coordinator.stopTimer() }
                        .buttonStyle(.borderless)
                } else {
                    Button(coordinator.timerStatus == .running ? "Pause" : "Resume") {
                        coordinator.toggleTimerPause()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .frame(minHeight: ClosedTimerActivityGeometry.controlHeight)
            .padding(.horizontal, 8)
            .background(Capsule().fill(Color.islandElevatedSurface))
            .overlay(Capsule().stroke(Color.islandBorder, lineWidth: 1))
            .padding(.horizontal, 8)
            .padding(.bottom, ClosedTimerActivityGeometry.bottomInset)
        }
        .foregroundStyle(Color.islandPrimaryText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Timer, \(timerText)")
    }

    private var timerText: String {
        if coordinator.timerStatus == .completed { return "Time's up" }
        let duration = coordinator.timerMode == .stopwatch
            ? coordinator.stopwatchElapsed
            : coordinator.timerRemaining
        let totalSeconds = max(0, Int(duration.rounded(.up)))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    @ViewBuilder
    var dragDetector: some View {
        if Defaults[.boringShelf] && vm.notchState == .closed && !vm.isScreenLocked {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
            vm.dropEvent = true
            ShelfStateViewModel.shared.load(providers)
            return true
        }
        } else {
            EmptyView()
        }
    }

    private func doOpen() {
        guard !vm.isScreenLocked else { return }
        vm.open()
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        guard !vm.isScreenLocked else {
            isHovering = false
            return
        }
        // Computer Use moves its pointer outside the captured app between
        // actions. Keep an explicit audit surface open so a visual audit can
        // navigate between pages; production hover-dismiss behavior is
        // unchanged.
        if UIAuditMode.isEnabled {
            isHovering = hovering
            return
        }
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()
        
        if hovering {
            withAnimation(interactionSpring) {
                isHovering = true
            }
            
            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }
            
            guard vm.notchState == .closed,
                  !coordinator.timerStatus.isVisible,
                  !coordinator.sneakPeek.show,
                  Defaults[.openNotchOnHover] else { return }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          !self.coordinator.sneakPeek.show else { return }
                    
                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(interactionSpring) {
                        self.isHovering = false
                    }
                    
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !self.vm.isMirrorSessionPinned && !SharingStateManager.shared.preventNotchClose {
                        self.vm.close()
                    }
                }
            }
        }
    }

    // MARK: - Gesture Handling

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        if phase == .ended {
            withAnimation(interactionSpring) { gestureProgress = .zero }
            return
        }

        withAnimation(interactionSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
            withAnimation(interactionSpring) {
                gestureProgress = .zero
            }
            doOpen()
        }
    }

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open && !vm.isHoveringCalendar else { return }

        withAnimation(interactionSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(interactionSpring) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            withAnimation(interactionSpring) {
                isHovering = false
            }
            if !SharingStateManager.shared.preventNotchClose { 
                gestureProgress = .zero
                vm.close()
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }
}

private struct SystemStateLiveActivity: View {
    @EnvironmentObject private var vm: BoringViewModel
    let type: SneakContentType
    let value: CGFloat

    private var title: String { SystemStatePresentation.title(for: type, value: value) }
    private var detail: String { SystemStatePresentation.detail(for: type, value: value) }

    var body: some View {
        VStack(spacing: 0) {
            // The physical camera housing remains clear; the state appears below it.
            Color.clear
                .frame(height: vm.effectiveClosedNotchHeight)

            HStack(spacing: 8) {
                Image(systemName: SystemStatePresentation.symbol(for: type, value: value))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(IslandTypography.control)
                    Text(detail)
                        .font(IslandTypography.metadata)
                        .foregroundStyle(Color.islandSecondaryText)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.islandPrimaryText)
            .frame(minWidth: 228, minHeight: 40, alignment: .leading)
            .padding(.horizontal, 12)
            .background(Capsule().fill(Color.islandElevatedSurface))
            .overlay(Capsule().stroke(Color.islandBorder, lineWidth: 1))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
    }
}

private struct ClipboardHistoryView: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @EnvironmentObject private var vm: BoringViewModel
    @Default(.clipboardHistoryEnabled) private var clipboardHistoryEnabled: Bool
    @State private var copiedEntryID: ClipboardEntry.ID?

    private var entries: [ClipboardEntry] {
        coordinator.clipboardEntries
    }

    private func updatePanelHeight() {
        vm.requestOpenHeight(
            IslandExpandedPageSizing.snippetsHeight(entryCount: entries.count),
            for: .clipboard
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Snippets", systemImage: "doc.on.clipboard")
                    .font(IslandTypography.title)
                Spacer()
                if !coordinator.clipboardEntries.isEmpty {
                    Button("Clear") { coordinator.clearClipboardHistory() }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Clear clipboard history")
                }
            }

            if clipboardHistoryEnabled || UIAuditMode.isEnabled {
                if entries.isEmpty {
                    CompactSnippetsEmptyState(
                        title: "No snippets yet",
                        message: "Copy text to add it here.",
                        systemImage: "doc.on.clipboard"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: IslandStyle.compactControlSpacing),
                                GridItem(.flexible(), spacing: IslandStyle.compactControlSpacing)
                            ],
                            alignment: .leading,
                            spacing: IslandStyle.compactControlSpacing
                        ) {
                            ForEach(entries) { entry in
                                HStack(spacing: IslandStyle.compactControlSpacing) {
                                    Text(entry.text)
                                        .font(IslandTypography.body)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                    Spacer(minLength: IslandStyle.compactControlSpacing)
                                    Button(copiedEntryID == entry.id ? "Copied" : "Copy") {
                                        coordinator.copyClipboardEntry(entry)
                                        copiedEntryID = entry.id
                                    }
                                        .buttonStyle(.borderless)
                                        .accessibilityLabel(
                                            copiedEntryID == entry.id
                                                ? "Copied to clipboard"
                                                : "Copy snippet to clipboard"
                                        )
                                    Button(role: .destructive) {
                                        coordinator.removeClipboardEntry(entry)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Delete snippet")
                                }
                                .padding(IslandStyle.compactControlPadding)
                                .background(
                                    Color.islandModuleSurface,
                                    in: RoundedRectangle(
                                        cornerRadius: IslandStyle.compactControlCornerRadius,
                                        style: .continuous
                                    )
                                )
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: IslandStyle.compactControlCornerRadius,
                                        style: .continuous
                                    )
                                    .stroke(
                                        Color.islandModuleBorder,
                                        lineWidth: IslandStyle.hairlineWidth
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            } else {
                ContentUnavailableView("Clipboard history is off", systemImage: "lock", description: Text("Enable it in Shelf settings to capture copied text."))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear(perform: updatePanelHeight)
        .onChange(of: entries.count) { _, _ in
            updatePanelHeight()
        }
        .padding(IslandStyle.modulePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.islandModuleSurface, in: RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous)
                .stroke(Color.islandModuleBorder, lineWidth: IslandStyle.hairlineWidth)
        }
        .accessibilityElement(children: .contain)
    }
}

/// `ContentUnavailableView` is intentionally generous for a full window. The
/// island already presents a title and search field, so its compact floor needs
/// a single quiet, readable empty-state row instead.
private struct CompactSnippetsEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.effectiveAccent)
                .frame(width: 28, height: 28)
                .background(Color.islandElevatedSurface, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IslandTypography.body.weight(.semibold))
                    .foregroundStyle(Color.islandPrimaryText)
                Text(message)
                    .font(IslandTypography.metadata)
                    .foregroundStyle(Color.islandSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.islandElevatedSurface,
            in: RoundedRectangle(cornerRadius: IslandStyle.compactControlCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IslandStyle.compactControlCornerRadius, style: .continuous)
                .stroke(Color.islandModuleBorder, lineWidth: IslandStyle.hairlineWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }

}

private struct ClosedSceneRetention: ViewModifier {
    @Binding var retainedScene: IslandScene
    let isSettledCompact: Bool
    let scene: IslandScene

    func body(content: Content) -> some View {
        content
            .onAppear(perform: captureIfClosed)
            .onChange(of: scene) { _, _ in captureIfClosed() }
            .onChange(of: isSettledCompact) { _, _ in captureIfClosed() }
    }

    private func captureIfClosed() {
        guard isSettledCompact else { return }
        retainedScene = scene
    }
}

private struct IslandSurface<Content: View>: View {
    let morphProgress: CGFloat
    let isHovering: Bool
    let usesFlushClosedGeometry: Bool
    let openSize: CGSize
    let closedSize: CGSize
    let closedContentWidth: CGFloat?
    let closedHeight: CGFloat
    let cornerRadiusScaling: Bool
    let shape: NotchShape
    let topCornerRadius: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(
                width: contentSize.width,
                height: contentSize.height,
                alignment: .top
            )
            .padding(
                .horizontal,
                horizontalPadding
            )
            .padding(.bottom, bottomPadding)
            // The shell owns a concrete frame in both states. This is what
            // lets the black Island itself morph like one bubble; otherwise
            // SwiftUI can resolve a content-driven width/height immediately
            // and leave only artwork and page controls to animate.
            .frame(width: surfaceSize.width, height: surfaceSize.height, alignment: .top)
            .background(Color.islandHardwareSurface)
            .clipShape(shape)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.islandHardwareSurface)
                    .frame(height: 1)
                    .padding(.horizontal, topCornerRadius)
            }
            .overlay {
                // Keep the closed physical bridge visually silent, while the
                // expanded surface gets a clear, accessibility-aware edge.
                shape
                    .stroke(Color.islandBorder.opacity(morphProgress), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: ((morphProgress > 0 || isHovering) && Defaults[.enableShadow])
                    ? IslandStyle.panelShadow : .clear,
                radius: interpolate(
                    IslandStyle.closedHoverShadowRadius,
                    cornerRadiusScaling ? IslandStyle.panelShadowRadius : IslandStyle.closedHoverShadowRadius
                )
            )
            .padding(.bottom, closedHeight == 0 ? 10 : 0)
    }

    private var horizontalInset: CGFloat {
        return cornerRadiusInsets.closed.bottom
    }

    private var openHorizontalInset: CGFloat {
        topCornerRadius + IslandStyle.openSurfacePadding
    }

    private var contentSize: CGSize {
        CGSize(
            width: interpolate(
                max(0, closedContentWidth ?? closedSize.width),
                max(0, openSize.width - openHorizontalInset * 2)
            ),
            height: interpolate(
                max(0, closedSize.height),
                max(0, openSize.height - IslandStyle.openSurfacePadding)
            )
        )
    }

    private var horizontalPadding: CGFloat {
        interpolate(
            usesFlushClosedGeometry ? 0 : horizontalInset,
            openHorizontalInset
        )
    }

    private var bottomPadding: CGFloat {
        interpolate(0, IslandStyle.openSurfacePadding)
    }

    private var surfaceSize: CGSize {
        CGSize(
            width: contentSize.width + horizontalPadding * 2,
            height: contentSize.height + bottomPadding
        )
    }

    private func interpolate(_ closed: CGFloat, _ open: CGFloat) -> CGFloat {
        closed + (open - closed) * morphProgress
    }
}

struct GeneralDropTargetDelegate: DropDelegate {
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        return false
    }
}

#Preview {
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
