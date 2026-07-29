//
//  MediaKeyInterceptor.swift
//  boringNotch
//
//  Created by Alexander on 2025-11-23.

import Foundation
import AppKit
import ApplicationServices
import Defaults
import AVFoundation

private let kSystemDefinedEventType = CGEventType(rawValue: 14)!

final class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()
    
    private enum NXKeyType: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
        case keyboardBrightnessUp = 21
        case keyboardBrightnessDown = 22
    }
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let step: Float = 1.0 / 16.0
    private var audioPlayer: AVAudioPlayer?
    private struct PendingKey: Hashable {
        let keyType: Int
        let option: Bool
        let shift: Bool
        let command: Bool
    }
    private var pendingKeyPresses: [PendingKey: Int] = [:]
    private var coalescingTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Accessibility (via XPC)
    
    func requestAccessibilityAuthorization() {
        XPCHelperClient.shared.requestAccessibilityAuthorization()
    }
    
    func ensureAccessibilityAuthorization(promptIfNeeded: Bool = false) async -> Bool {
        await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: promptIfNeeded)
    }
    
    // MARK: - Event Tap
    
    func start(promptIfNeeded: Bool = false) async {
        guard eventTap == nil else { return }
        
        // Ensure HUD replacement is enabled
        guard Defaults[.hudReplacement] else {
            stop()
            return
        }
        
        // Check accessibility authorization
        let authorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        if !authorized {
            if promptIfNeeded {
                let granted = await ensureAccessibilityAuthorization(promptIfNeeded: true)
                guard granted else { return }
            } else {
                return
            }
        }
        
        let mask = CGEventMask(1 << kSystemDefinedEventType.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, cgEvent, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(cgEvent) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                return interceptor.handleEvent(cgEvent)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        if let eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            if let runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
    
    func stop() {
        coalescingTask?.cancel()
        coalescingTask = nil
        pendingKeyPresses.removeAll()
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        // Settings can disable replacement while a queued event is still in flight.
        guard Defaults[.hudReplacement] else { return Unmanaged.passRetained(cgEvent) }
        // Ensure the CGEvent has a valid type before converting to NSEvent
        guard cgEvent.type != .null else {
            return Unmanaged.passRetained(cgEvent)
        }
        guard let nsEvent = NSEvent(cgEvent: cgEvent),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(cgEvent)
        }
        
        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let stateByte = ((data1 & 0xFF00) >> 8)
        
        // 0xA = key down, 0xB = key up. Only handle key down.
        guard stateByte == 0xA,
              let keyType = NXKeyType(rawValue: keyCode) else {
            return Unmanaged.passRetained(cgEvent)
        }
        
        let flags = nsEvent.modifierFlags
        let option = flags.contains(.option)
        let shift = flags.contains(.shift)
        let command = flags.contains(.command)
        
        // Handle option key action (without shift)
        if option && !shift {
            if handleOptionAction(for: keyType, command: command) {
                return nil
            }
        }
        
        // Handle normal key press
        enqueueKeyPress(keyType: keyType, option: option, shift: shift, command: command)
        return nil
    }
    
    private func handleOptionAction(for keyType: NXKeyType, command: Bool) -> Bool {
        let action = Defaults[.optionKeyAction]
        
        switch action {
        case .openSettings:
            openSystemSettings(for: keyType, command: command)
            return true
        case .showHUD:
            showHUD(for: keyType, command: command)
            return true
        case .none:
            return true
        }
    }
    
    private func prepareAudioPlayerIfNeeded() {
        guard audioPlayer == nil else { return }

        let defaultPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
        if FileManager.default.fileExists(atPath: defaultPath) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: defaultPath))
                print("🔊 [MediaKeyInterceptor] Loaded default Bezel audio from: \(defaultPath)")
            } catch {
                print("⚠️ [MediaKeyInterceptor] Failed to init AVAudioPlayer with default path \(defaultPath): \(error.localizedDescription)")
            }
        } else {
            print("⚠️ [MediaKeyInterceptor] Default bezel audio not found at: \(defaultPath)")
        }

        if let player = audioPlayer {
            player.volume = 1.0
            player.numberOfLoops = 0
            player.prepareToPlay()
        }
    }

    private func playFeedbackSound() {
        guard let feedback = UserDefaults.standard.persistentDomain(forName: "NSGlobalDomain")?["com.apple.sound.beep.feedback"] as? Int,
              feedback == 1 else { return }

        prepareAudioPlayerIfNeeded()
        guard let player = audioPlayer else {
            print("⚠️ [MediaKeyInterceptor] No audio player available to play feedback sound")
            return
        }
        if let url = player.url {
            print("🔊 [MediaKeyInterceptor] Playing feedback sound from: \(url.path)")
        } else {
            print("🔊 [MediaKeyInterceptor] Playing feedback sound (no url available for AVAudioPlayer)")
        }
        if player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
        player.play()
    }

    private func enqueueKeyPress(keyType: NXKeyType, option: Bool, shift: Bool, command: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, Defaults[.hudReplacement] else { return }
            let key = PendingKey(keyType: keyType.rawValue, option: option, shift: shift, command: command)
            self.pendingKeyPresses[key, default: 0] += 1
            guard self.coalescingTask == nil else { return }
            self.coalescingTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(24))
                guard let self, !Task.isCancelled else { return }
                let pending = self.pendingKeyPresses
                self.pendingKeyPresses.removeAll()
                self.coalescingTask = nil
                for (key, count) in pending {
                    guard let type = NXKeyType(rawValue: key.keyType) else { continue }
                    self.handleKeyPress(
                        keyType: type,
                        option: key.option,
                        shift: key.shift,
                        command: key.command,
                        repeatCount: count
                    )
                }
            }
        }
    }

    @MainActor
    private func handleKeyPress(
        keyType: NXKeyType,
        option: Bool,
        shift: Bool,
        command: Bool,
        repeatCount: Int
    ) {
        let stepDivisor: Float = (option && shift) ? 4.0 : 1.0
        let multiplier = Float(max(repeatCount, 1))
        
        switch keyType {
        case .soundUp:
            playFeedbackSound()
            VolumeManager.shared.adjust(delta: step * multiplier / stepDivisor)
        case .soundDown:
            playFeedbackSound()
            VolumeManager.shared.adjust(delta: -(step * multiplier / stepDivisor))
        case .mute:
            VolumeManager.shared.toggleMuteAction()
        case .brightnessUp, .keyboardBrightnessUp:
            let delta = step * multiplier / stepDivisor
            adjustBrightness(delta: delta, keyboard: keyType == .keyboardBrightnessUp || command)
        case .brightnessDown, .keyboardBrightnessDown:
            let delta = -(step * multiplier / stepDivisor)
            adjustBrightness(delta: delta, keyboard: keyType == .keyboardBrightnessDown || command)
        }
    }
    
    @MainActor
    private func adjustBrightness(delta: Float, keyboard: Bool) {
        if keyboard {
            KeyboardBacklightManager.shared.setRelative(delta: delta)
        } else {
            BrightnessManager.shared.setRelative(delta: delta)
        }
    }
    
    private func showHUD(for keyType: NXKeyType, command: Bool) {
        Task { @MainActor in
            switch keyType {
            case .soundUp, .soundDown, .mute:
                let v = VolumeManager.shared.rawVolume
                BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .volume, value: CGFloat(v))
            case .brightnessUp, .brightnessDown:
                if command {
                    let v = KeyboardBacklightManager.shared.rawBrightness
                    BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .backlight, value: CGFloat(v))
                } else {
                    let v = BrightnessManager.shared.rawBrightness
                    BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .brightness, value: CGFloat(v))
                }
            case .keyboardBrightnessUp, .keyboardBrightnessDown:
                let v = KeyboardBacklightManager.shared.rawBrightness
                BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .backlight, value: CGFloat(v))
            }
        }
    }
    
    private func openSystemSettings(for keyType: NXKeyType, command: Bool) {
        let urlString: String
        
        switch keyType {
        case .soundUp, .soundDown, .mute:
            urlString = "x-apple.systempreferences:com.apple.preference.sound"
        case .brightnessUp, .brightnessDown:
            if command {
                urlString = "x-apple.systempreferences:com.apple.preference.keyboard"
            } else {
                urlString = "x-apple.systempreferences:com.apple.preference.displays"
            }
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            urlString = "x-apple.systempreferences:com.apple.preference.keyboard"
        }
        
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
