import AppKit
import Foundation
import SwiftUI

struct AppleNote: Identifiable, Equatable {
    let id: String
    let title: String
    let preview: String
}

/// A native text view lets the visible text container use the exact same inset
/// as the SwiftUI placeholder. `TextEditor` does not expose that AppKit value.
struct QuickNoteTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.font = .systemFont(ofSize: 15)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.setAccessibilityLabel("Quick note editor")

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              textView.string != text
        else { return }
        textView.string = text
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QuickNoteTextEditor

        init(parent: QuickNoteTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// A lightweight Notes.app bridge. Draft text stays in the editor until the
/// user explicitly saves it, at which point Notes owns the data completely.
@MainActor
final class AppleNotesStore: ObservableObject {
    static let shared = AppleNotesStore()

    @Published private(set) var recentNotes: [AppleNote] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private var lastRefreshDate: Date?
    private let refreshInterval: TimeInterval = 10 * 60
    private var refreshTimer: Timer?

    private init() {
        // Notes does not publish per-note change notifications to other apps.
        // Refresh the cache off-screen while MacIsland is running so entries
        // deleted directly in Notes do not persist until a relaunch.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshIfNeeded()
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func preload() async {
        await refreshIfNeeded()
    }

    func refreshIfNeeded() async {
        if let lastRefreshDate,
           Date.now.timeIntervalSince(lastRefreshDate) < refreshInterval {
            return
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await AppleScriptHelper.execute("""
            tell application "Notes"
                set noteList to notes of default account
                set recentNotes to {}
                repeat with noteItem in noteList
                    set end of recentNotes to {id of noteItem as text, name of noteItem as text, plaintext of noteItem as text}
                    if (count of recentNotes) is 12 then exit repeat
                end repeat
                return recentNotes
            end tell
            """)
            recentNotes = Self.notes(from: result)
            lastRefreshDate = .now
        } catch {
            errorMessage = "Allow MacIsland to access Notes to show your recent notes."
        }
    }

    func createNote(from draft: String) async -> Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }

        do {
            let result = try await AppleScriptHelper.execute("""
            tell application "Notes"
                set targetFolder to default folder of default account
                set createdNote to make new note at targetFolder with properties {body:\(Self.appleScriptString(text))}
                show createdNote
                return id of createdNote as text
            end tell
            """)
            guard let identifier = result?.stringValue else { return false }
            let title = Self.firstLine(of: text)
            recentNotes.insert(AppleNote(id: identifier, title: title, preview: text), at: 0)
            recentNotes = Array(recentNotes.prefix(12))
            return true
        } catch {
            errorMessage = "MacIsland could not create the note. Check Notes access and try again."
            return false
        }
    }

    func open(_ note: AppleNote) async {
        do {
            _ = try await AppleScriptHelper.execute("""
            tell application "Notes"
                show note id \(Self.appleScriptString(note.id))
                activate
            end tell
            """)
        } catch {
            errorMessage = "MacIsland could not open that note."
        }
    }

    private static func notes(from descriptor: NSAppleEventDescriptor?) -> [AppleNote] {
        guard let descriptor else { return [] }
        return (1...descriptor.numberOfItems).compactMap { index in
            guard let row = descriptor.atIndex(index), row.numberOfItems >= 3,
                  let id = row.atIndex(1)?.stringValue,
                  let title = row.atIndex(2)?.stringValue,
                  let body = row.atIndex(3)?.stringValue else { return nil }
            return AppleNote(id: id, title: title, preview: body)
        }
    }

    private static func firstLine(of text: String) -> String {
        text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "New Note"
    }

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}

struct QuickNotesView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var notes = AppleNotesStore.shared
    @State private var draft = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Quick Notes", systemImage: "note.text")
                    .font(IslandTypography.title)
                Spacer()
                Button {
                    Task { await openNotesApp() }
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Open Notes")
            }

            ZStack(alignment: .topLeading) {
                QuickNoteTextEditor(text: $draft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if draft.isEmpty {
                    Text("Type a quick note…")
                        .font(IslandTypography.body)
                        .foregroundStyle(Color.islandSecondaryText)
                        // Mirrors NSTextView's text-container inset exactly.
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 102)
            .background(Color.islandElevatedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.islandModuleBorder, lineWidth: IslandStyle.hairlineWidth) }
            .accessibilityLabel("Quick note editor")

            HStack {
                if let errorMessage = notes.errorMessage {
                    Text(errorMessage)
                        .font(IslandTypography.metadata)
                        .foregroundStyle(Color.islandSecondaryText)
                        .lineLimit(2)
                } else {
                    Text("First line becomes the title · saves to your default folder")
                        .font(IslandTypography.metadata)
                        .foregroundStyle(Color.islandSecondaryText)
                }
                Spacer(minLength: 8)
                Button("Add to Notes", systemImage: "plus") {
                    Task {
                        isSaving = true
                        if await notes.createNote(from: draft) { draft = "" }
                        isSaving = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .accessibilityLabel("Add quick note to Notes")
            }

            if !notes.recentNotes.isEmpty {
                Text("Recent in Notes")
                    .font(IslandTypography.metadata.weight(.semibold))
                    .foregroundStyle(Color.islandSecondaryText)
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(notes.recentNotes.prefix(3)) { note in
                            Button { Task { await notes.open(note) } } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title).font(IslandTypography.control).lineLimit(1)
                                    Text(note.preview).font(IslandTypography.metadata).foregroundStyle(Color.islandSecondaryText).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .background(Color.islandElevatedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .frame(height: min(CGFloat(notes.recentNotes.prefix(3).count) * 44 + 8, 140))
            }
        }
        .padding(IslandStyle.modulePadding)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.islandModuleSurface, in: RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: IslandStyle.moduleCornerRadius, style: .continuous).stroke(Color.islandModuleBorder, lineWidth: IslandStyle.hairlineWidth) }
        // Keep the Notes module visibly inside the Island silhouette instead
        // of letting its gray surface read as part of the outer border.
        .padding(.bottom, IslandStyle.openSurfacePadding)
        .onAppear {
            vm.requestOpenHeight(
                IslandExpandedPageSizing.notesHeight(recentNoteCount: notes.recentNotes.count),
                for: .notes
            )
        }
        .onChange(of: notes.recentNotes.count) { _, count in
            vm.requestOpenHeight(IslandExpandedPageSizing.notesHeight(recentNoteCount: count), for: .notes)
        }
    }

    private func openNotesApp() async {
        _ = try? await AppleScriptHelper.execute("tell application \"Notes\" to activate")
    }
}
