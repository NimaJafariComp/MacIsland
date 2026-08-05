//
//  BoringNotchWindow.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 06/08/24.
//

import Cocoa

class BoringNotchWindow: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )
        
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        
        isReleasedWhenClosed = false
        level = .mainMenu + 3
        hasShadow = false
    }
    
    override var canBecomeKey: Bool {
        // The island contains real text inputs (for example Quick Notes), so
        // it must be eligible for key focus in normal production launches.
        true
    }
    
    override var canBecomeMain: Bool {
        // Text entry is a deliberate interaction, so allow the panel to
        // activate the app and receive the keyboard responder chain.
        true
    }

    override func sendEvent(_ event: NSEvent) {
        // A borderless floating panel does not automatically become key on a
        // click the way a titled app window does. Promote it before dispatch
        // so AppKit can deliver that same click to an NSTextView/TextEditor.
        if event.type == .leftMouseDown, !isKeyWindow {
            makeKey()
        }
        super.sendEvent(event)
    }
}
