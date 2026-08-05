//
//  ShelfItemView.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import SwiftUI
import AppKit

struct ShelfView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject var tvm = ShelfStateViewModel.shared
    @StateObject var selection = ShelfSelectionModel.shared
    @StateObject private var quickLookService = QuickLookService()
    @State private var confirmsClear = false
    private let spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: 12) {
            FileShareView()
                .frame(width: 96)
                .environmentObject(vm)
            panel
                .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    handleDrop(providers: providers)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Bind Quick Look to shelf selection
        .onChange(of: selection.selectedIDs) {
            updateQuickLookSelection()
        }
        .quickLookPresenter(using: quickLookService)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !selection.isDragging else { return false }
        vm.dropEvent = true
        ShelfStateViewModel.shared.load(providers)
        return true
    }
    
    private func updateQuickLookSelection() {
        guard quickLookService.isQuickLookOpen && !selection.selectedIDs.isEmpty else { return }
        
        let selectedItems = selection.selectedItems(in: tvm.items)
        let urls: [URL] = selectedItems.compactMap { item in
            if let fileURL = item.fileURL {
                return fileURL
            }
            if case .link(let url) = item.kind {
                return url
            }
            return nil
        }
        
        if !urls.isEmpty {
            quickLookService.updateSelection(urls: urls)
        }
    }

    var panel: some View {
        RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous)
            .fill(Color.islandModuleSurface)
            .overlay {
                content
                    .padding(IslandStyle.modulePadding)
            }
            .overlay {
                RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous)
                    .stroke(
                        vm.dragDetectorTargeting
                            ? Color.islandFocus.opacity(0.9)
                            : Color.islandModuleBorder,
                        lineWidth: vm.dragDetectorTargeting ? 2 : 1
                    )
            }
            .shadow(color: IslandStyle.panelShadow, radius: IslandStyle.panelShadowRadius, x: 0, y: 3)
            .animation(IslandMotion.content, value: vm.dragDetectorTargeting)
            .contentShape(Rectangle())
            .onTapGesture { selection.clear() }
            .alert("Clear Shelf?", isPresented: $confirmsClear) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    quickLookService.hide()
                    tvm.removeAll()
                    selection.clear()
                }
            } message: {
                Text("Remove all files and links from Shelf?")
            }
    }

    var content: some View {
        Group {
            if tvm.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .symbolVariant(.fill)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.islandSecondaryText, Color.islandBorder)
                        .imageScale(.large)
                    
                    Text("Shelf is empty")
                        .foregroundStyle(Color.islandPrimaryText)
                        .font(IslandTypography.title)
                    Text("Drop files or links here")
                        .foregroundStyle(Color.islandSecondaryText)
                        .font(IslandTypography.metadata)
                    if let dropErrorMessage = tvm.dropErrorMessage {
                        Label(dropErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(IslandTypography.metadata)
                            .foregroundStyle(Color.islandWarning)
                            .accessibilityLabel(dropErrorMessage)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Shelf is empty. Drop files or links here.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    shelfToolbar

                    if let dropErrorMessage = tvm.dropErrorMessage {
                        Label(dropErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(IslandTypography.metadata)
                            .foregroundStyle(Color.islandWarning)
                            .accessibilityLabel(dropErrorMessage)
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: spacing) {
                            ForEach(tvm.items) { item in
                                ShelfItemView(item: item)
                                    .environmentObject(quickLookService)
                            }
                        }
                    }
                    .padding(-spacing)
                    .scrollIndicators(.never)
                    .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                        handleDrop(providers: providers)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if tvm.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(6)
                    .accessibilityLabel("Adding items to Shelf")
            }
        }
        .onAppear {
            ShelfStateViewModel.shared.cleanupInvalidItems()
        }
    }

    private var shelfToolbar: some View {
        HStack(spacing: 6) {
            Label("\(tvm.items.count) \(tvm.items.count == 1 ? "item" : "items")", systemImage: "tray.full")
                .font(IslandTypography.metadata.weight(.medium))
                .foregroundStyle(Color.islandSecondaryText)

            Spacer(minLength: 0)

            if selection.hasSelection {
                Button(role: .destructive) {
                    selection.selectedItems(in: tvm.items).forEach(tvm.remove)
                    selection.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.delete, modifiers: [])
                .help("Remove selected items")
                .accessibilityLabel("Remove selected Shelf items")
            }

            Button {
                selection.moveSelection(by: -1, in: tvm.items)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.leftArrow, modifiers: [.control])
            .disabled(tvm.items.isEmpty)
            .help("Select previous item")
            .accessibilityLabel("Select previous Shelf item")

            Button {
                selection.moveSelection(by: 1, in: tvm.items)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.rightArrow, modifiers: [.control])
            .disabled(tvm.items.isEmpty)
            .help("Select next item")
            .accessibilityLabel("Select next Shelf item")

            Menu {
                Button("Clear Shelf", role: .destructive) { confirmsClear = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help("Shelf actions")
            .accessibilityLabel("Shelf actions")
        }
    }
}
