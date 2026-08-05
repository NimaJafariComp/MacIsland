//
//  WebcamView.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 19/08/24.
//

import AVFoundation
import Defaults
import SwiftUI

enum MirrorPresentation {
    static func toggledShape(from shape: MirrorShapeEnum) -> MirrorShapeEnum {
        shape == .circle ? .rectangle : .circle
    }

    static func status(
        isRunning: Bool,
        cameraAvailable: Bool,
        authorizationStatus: AVAuthorizationStatus,
        managerMessage: String?
    ) -> String {
        if isRunning { return "Live preview" }
        if !cameraAvailable { return "No camera available" }
        switch authorizationStatus {
        case .denied, .restricted:
            return "Camera access is required"
        case .notDetermined:
            return "Camera access will be requested when opened"
        default:
            return managerMessage ?? "Camera is ready when you are"
        }
    }
}

private struct MirrorPreviewShape: Shape {
    let shape: MirrorShapeEnum

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .circle:
            Circle().path(in: rect)
        case .rectangle:
            RoundedRectangle(cornerRadius: 18, style: .continuous).path(in: rect)
        }
    }
}

struct CameraPreviewView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager: WebcamManager
    /// Mirror passes its observed setting directly so the mask updates in the
    /// same view transaction as the control tap. Home falls back to Defaults.
    var shape: MirrorShapeEnum?
    var ringLightActive = false
    var ringLightBrightness = 0.96
    
    var body: some View {
        GeometryReader { geometry in
            let previewShape = MirrorPreviewShape(shape: shape ?? Defaults[.mirrorShape])
            ZStack {
                if let previewLayer = webcamManager.previewLayer {
                    CameraPreviewLayerView(previewLayer: previewLayer)
                        .scaleEffect(x: -1, y: 1)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(webcamManager.isSessionRunning ? 1 : 0)
                }

                if !webcamManager.isSessionRunning {
                    Color.islandElevatedSurface
                    VStack(spacing: 8) {
                        Image(systemName: webcamManager.authorizationStatus == .denied || webcamManager.authorizationStatus == .restricted ? "exclamationmark.triangle" : "web.camera")
                            .foregroundStyle(Color.islandSecondaryText)
                            .font(.system(size: geometry.size.width / 3.5))
                        Text(webcamManager.statusMessage ?? (webcamManager.authorizationStatus == .denied ? "Camera access denied" : "Mirror"))
                            .font(.caption2)
                            .foregroundColor(Color.islandSecondaryText)
                    }
                }
            }
            .clipShape(previewShape)
            .overlay { previewShape.stroke(Color.islandBorder, lineWidth: IslandStyle.hairlineWidth) }
            .overlay {
                if ringLightActive {
                    previewShape
                        .stroke(
                            Color.white.opacity(ringLightBrightness),
                            lineWidth: 34
                        )
                        .blur(radius: 26)
                    previewShape
                        .stroke(
                            Color.white.opacity(ringLightBrightness),
                            lineWidth: 16
                        )
                        .blur(radius: 8)
                    previewShape
                        .stroke(
                            Color.white.opacity(ringLightBrightness),
                            lineWidth: 7
                        )
                }
            }
            .compositingGroup()
            .onDisappear {
                webcamManager.stopSession()
                vm.isCameraExpanded = false
                vm.isMirrorRingLightActive = false
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
}

/// The large, centered camera destination. It owns the user-initiated camera
/// lifecycle while `CameraPreviewView` remains reusable on Home.
struct MirrorView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var webcamManager = WebcamManager.shared
    @Default(.mirrorShape) private var mirrorShape

    private var isRunning: Bool { webcamManager.isSessionRunning }

    private var statusText: String {
        MirrorPresentation.status(
            isRunning: isRunning,
            cameraAvailable: webcamManager.cameraAvailable,
            authorizationStatus: webcamManager.authorizationStatus,
            managerMessage: webcamManager.statusMessage
        )
    }

    private var primaryTitle: String {
        isRunning ? "Close Mirror" : "Open Mirror"
    }

    var body: some View {
        GeometryReader { proxy in
            let previewSide = max(180, min(proxy.size.width - 128, proxy.size.height - 24))

            HStack(spacing: 12) {
                MirrorControlRail {
                    MirrorSideButton(
                        icon: isRunning ? "video.slash" : "video",
                        label: primaryTitle,
                        help: isRunning ? "Stop camera preview" : "Start camera preview",
                        action: toggleMirror
                    )
                    .disabled(!webcamManager.cameraAvailable && !isRunning)
                }

                CameraPreviewView(
                    webcamManager: webcamManager,
                    shape: mirrorShape,
                    ringLightActive: vm.isMirrorRingLightActive,
                    ringLightBrightness: vm.mirrorRingLightBrightness
                )
                    .frame(width: previewSide, height: previewSide)
                    .accessibilityLabel("Camera mirror preview")
                    .accessibilityValue(isRunning ? "Live" : statusText)

                MirrorControlRail {
                    MirrorSideButton(
                        icon: mirrorShape == .circle ? "rectangle" : "circle",
                        label: mirrorShape == .circle ? "Use square mirror" : "Use circular mirror",
                        help: mirrorShape == .circle ? "Switch to square mirror" : "Switch to circular mirror",
                        action: toggleShape
                    )
                    RingLightControl(
                        isActive: $vm.isMirrorRingLightActive,
                        brightness: $vm.mirrorRingLightBrightness
                    )
                    MirrorSideButton(
                        icon: "gearshape",
                        label: "Open Mirror Settings",
                        help: "Open Mirror Settings",
                        action: openMirrorSettings
                    )
                }
            }
            .padding(.horizontal, IslandStyle.homeHorizontalInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mirror")
        .onReceive(NotificationCenter.default.publisher(for: .settingsWindowDidClose)) { _ in
            vm.isMirrorSettingsPresented = false
        }
        .onDisappear {
            vm.isMirrorSettingsPresented = false
        }
    }

    private func toggleMirror() {
        // Choosing the explicit Open action is the user's intent to enable the
        // optional module and, when necessary, to receive macOS's camera prompt.
        if isRunning {
            // Stopping capture is not a dismissal request. Keep the Mirror
            // page open while the pointer remains in the Island; the normal
            // hover-off path owns any later collapse.
            vm.toggleCameraPreview()
            return
        }
        Defaults[.showMirror] = true
        vm.toggleCameraPreview()
    }

    private func toggleShape() {
        mirrorShape = MirrorPresentation.toggledShape(from: mirrorShape)
    }

    private func openMirrorSettings() {
        vm.isMirrorSettingsPresented = true
        SettingsWindowController.shared.showWindow()
    }
}

private struct RingLightControl: View {
    @Binding var isActive: Bool
    @Binding var brightness: Double

    var body: some View {
        VStack(spacing: 10) {
            MirrorSideButton(
                icon: isActive ? "sun.max.fill" : "sun.max",
                label: isActive ? "Turn off mirror ring light" : "Turn on mirror ring light",
                help: isActive
                    ? "Turn off the light around the mirror"
                    : "Light the border around the mirror",
                action: { isActive.toggle() },
                isSelected: isActive
            )

            if isActive {
                VerticalRingLightBrightness(value: $brightness)
            }
        }
        .animation(IslandMotion.interaction, value: isActive)
    }
}

/// SwiftUI's stock Slider rotates visually but retains a horizontal hit region.
/// This control owns vertical hit testing, so clicking or dragging higher always
/// increases brightness and clicking or dragging lower always decreases it.
private struct VerticalRingLightBrightness: View {
    @Binding var value: Double
    private let range: ClosedRange<Double> = 0.6...1
    private let thumbSize: CGFloat = 18

    private var normalizedValue: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        GeometryReader { proxy in
            let trackHeight = max(1, proxy.size.height - thumbSize)
            let thumbY = thumbSize / 2 + (1 - normalizedValue) * trackHeight

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.islandElevatedSurface)
                    .frame(width: 5)
                    .padding(.vertical, thumbSize / 2)
                Capsule()
                    .fill(Color.yellow)
                    .frame(width: 5, height: max(0, normalizedValue * trackHeight))
                    .padding(.bottom, thumbSize / 2)
                Circle()
                    .fill(Color.islandPrimaryText)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .position(x: proxy.size.width / 2, y: thumbY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(at: gesture.location.y, in: proxy.size.height)
                    }
            )
        }
        .frame(width: IslandStyle.minimumHitTarget, height: 76)
        .accessibilityElement()
        .accessibilityLabel("Mirror ring light brightness")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
        .help("Adjust mirror ring light brightness")
    }

    private func updateValue(at location: CGFloat, in height: CGFloat) {
        let trackHeight = max(1, height - thumbSize)
        let clampedY = min(max(location - thumbSize / 2, 0), trackHeight)
        let normalized = 1 - Double(clampedY / trackHeight)
        value = min(max(range.lowerBound + normalized * (range.upperBound - range.lowerBound), range.lowerBound), range.upperBound)
    }
}

private struct MirrorControlRail<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 8) {
            content
        }
        .frame(width: 44)
        .padding(.vertical, 8)
        .background(Color.islandModuleSurface, in: Capsule())
        .overlay {
            Capsule().stroke(Color.islandModuleBorder, lineWidth: IslandStyle.hairlineWidth)
        }
    }
}

private struct MirrorSideButton: View {
    let icon: String
    let label: String
    let help: String
    let action: () -> Void
    var isSelected = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(IslandTypography.control)
            .foregroundStyle(isSelected ? Color.black : Color.islandPrimaryText)
            .frame(width: IslandStyle.minimumHitTarget, height: IslandStyle.minimumHitTarget)
            .background {
                Circle()
                    .fill(isSelected ? Color.yellow : Color.clear)
            }
            .overlay {
                Circle()
                    .stroke(
                        isSelected ? Color.white.opacity(0.55) : Color.clear,
                        lineWidth: IslandStyle.hairlineWidth
                    )
            }
            .shadow(color: isSelected ? Color.yellow.opacity(0.45) : .clear, radius: 5)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(help)
    }
}

struct CameraPreviewLayerView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer = previewLayer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = nsView.bounds
        CATransaction.commit()
    }
}

#Preview {
    CameraPreviewView(webcamManager: .shared)
}
