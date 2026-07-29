//
//  FileShareView.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct FileShareView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @StateObject private var quickShare = QuickShareService.shared
    @Default(.quickShareProvider) var quickShareProvider: String

    @State private var hostView: NSView?
    @State private var interactionNonce: UUID = .init()
    @State private var isProcessing = false
    
    private var selectedProvider: QuickShareProvider {
        quickShare.availableProviders.first(where: { $0.id == quickShareProvider }) ?? QuickShareProvider(id: "System Share Menu", imageData: nil, supportsRawText: true)
    }

    var body: some View {
        dropArea
            .background(NSViewHost(view: $hostView))
            .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data, .image], isTargeted: $vm.dropZoneTargeting) { providers in
                interactionNonce = .init()
                vm.dropEvent = true
                Task { await handleDrop(providers) }
                return true
            }
            .onTapGesture {
                Task {
                    await handleClick()
                }
            }
    }

    private var dropArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.islandElevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            vm.dropZoneTargeting
                                ? Color.islandFocus.opacity(0.9)
                                : Color.islandBorder,
                            lineWidth: vm.dropZoneTargeting ? 2 : 1
                        )
                )
                .shadow(color: IslandStyle.panelShadow, radius: 5, x: 0, y: 2)

            // Content
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(vm.dropZoneTargeting ? Color.islandPressedSurface : Color.islandElevatedSurface)
                        .frame(width: 55, height: 55)
                    Image(systemName: "square.and.arrow.up")
                    Group {
                        if let imgData = selectedProvider.imageData, let nsImg = NSImage(data: imgData) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .frame(width: 34, height: 34)
                        .foregroundStyle(vm.dropZoneTargeting ? Color.islandFocus : Color.islandSecondaryText)
                        .scaleEffect(
                            vm.dropZoneTargeting ? 1.06 : 1.0
                        )
                        .animation(IslandMotion.interaction, value: vm.dropZoneTargeting)
                }

                Text(selectedProvider.id)
                    .font(IslandTypography.title)
                    .foregroundColor(Color.islandPrimaryText)

            }
            .padding(18)
            
            // Loading overlay
            if isProcessing || quickShare.isPickerOpen {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.islandScrim)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.islandPrimaryText))
                            .scaleEffect(0.8)
                    )
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Share files with \(selectedProvider.id)")
    }

    // MARK: - Actions

    private func handleDrop(_ providers: [NSItemProvider]) async {
        isProcessing = true
        defer { isProcessing = false }
        await quickShare.shareDroppedFiles(providers, using: selectedProvider, from: hostView)
    }
    
    private func handleClick() async {
        await quickShare.showFilePicker(for: selectedProvider, from: hostView)
    }
}

// MARK: - Host NSView extractor for anchoring share sheet

private struct NSViewHost: NSViewRepresentable {
    @Binding var view: NSView?
    
    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        DispatchQueue.main.async { self.view = v }
        return v
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.view = nsView }
    }
}
