//
//  WebcamManager.swift
//  MacIsland
//

import AVFoundation
import os
import SwiftUI

/// Narrow camera seam used by presentation code and failure-path tests.
protocol CameraSessionControlling: AnyObject {
    var authorizationStatus: AVAuthorizationStatus { get }
    var cameraAvailable: Bool { get }
    var isSessionRunning: Bool { get }
    func requestAccessAndStart()
    func startSession()
    func stopSession()
}

/// Owns every AVCaptureSession mutation on `sessionQueue`. SwiftUI only observes
/// published presentation state; it never configures or starts a camera session.
final class WebcamManager: NSObject, ObservableObject {
    static let shared = WebcamManager()
    private static let lifecycleLog = OSLog(subsystem: "com.macisland.app", category: "CameraLifecycle")

    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    @Published private(set) var isSessionRunning = false
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var cameraAvailable = false
    @Published private(set) var statusMessage: String?

    private let sessionQueue = DispatchQueue(label: "MacIsland.WebcamManager.SessionQueue", qos: .userInitiated)
    private var captureSession: AVCaptureSession?
    private var wantsSession = false
    private var runtimeErrorObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?

    private override init() {
        super.init()
        refreshAuthorizationStatus()
        refreshCameraAvailability()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWasDisconnected),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWasConnected),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let runtimeErrorObserver { NotificationCenter.default.removeObserver(runtimeErrorObserver) }
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
    }

    func refreshAuthorizationStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        publishAuthorizationStatus(status)
        if status != .authorized { stopSession() }
    }

    func refreshCameraAvailability() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let hasCamera = self.videoDevice() != nil
            self.publishCameraAvailability(hasCamera)
            if !hasCamera { self.publishStatusMessage("No camera available") }
        }
    }

    /// Permission remains a user action. Start occurs only after this explicit request.
    func requestAccessAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        publishAuthorizationStatus(status)
        guard status == .notDetermined else {
            if status == .authorized { startSession() }
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            self.publishAuthorizationStatus(granted ? .authorized : .denied)
            guard granted else {
                self.publishStatusMessage("Camera access denied")
                return
            }
            self.startSession()
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsSession = true
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                self.publishAuthorizationStatus(AVCaptureDevice.authorizationStatus(for: .video))
                self.publishStatusMessage("Camera access required")
                return
            }

            guard let session = self.configureSessionIfNeeded() else { return }
            guard self.wantsSession, !session.isRunning else { return }
            let signpostID = OSSignpostID(log: Self.lifecycleLog)
            os_signpost(.begin, log: Self.lifecycleLog, name: "Camera Startup", signpostID: signpostID)
            session.startRunning()
            os_signpost(.end, log: Self.lifecycleLog, name: "Camera Startup", signpostID: signpostID)
            self.publishSessionRunning(session.isRunning)
            if session.isRunning { self.publishStatusMessage(nil) }
        }
    }

    /// Stops capture immediately but keeps configuration ready for a deliberate reopen.
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsSession = false
            if self.captureSession?.isRunning == true { self.captureSession?.stopRunning() }
            self.publishSessionRunning(false)
        }
    }

    /// Stops hardware work for sleep without forgetting a visible mirror.
    func pauseSessionForSleep() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession?.isRunning == true { self.captureSession?.stopRunning() }
            self.publishSessionRunning(false)
        }
    }

    /// Called after wake only when mirror is still visible and previously requested.
    func resumeSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, self.wantsSession else { return }
            self.startSession()
        }
    }

    private func configureSessionIfNeeded() -> AVCaptureSession? {
        if let captureSession { return captureSession }
        guard let device = videoDevice() else {
            publishCameraAvailability(false)
            publishStatusMessage("No camera available")
            return nil
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                publishStatusMessage("Camera unavailable")
                return nil
            }
            session.addInput(input)
        } catch {
            publishStatusMessage("Camera unavailable. Another app may be using it.")
            return nil
        }

        captureSession = session
        observeSession(session)
        publishCameraAvailability(true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            self.previewLayer = layer
        }
        return session
    }

    private func observeSession(_ session: AVCaptureSession) {
        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: session,
            queue: nil
        ) { [weak self] _ in
            self?.handleSessionFailure("Camera unavailable. Another app may be using it.")
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: session,
            queue: nil
        ) { [weak self] _ in
            self?.handleSessionFailure("Camera interrupted")
        }
    }

    private func handleSessionFailure(_ message: String) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession?.stopRunning()
            self.publishSessionRunning(false)
            self.publishStatusMessage(message)
        }
    }

    private func videoDevice() -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.first
    }

    private func publishAuthorizationStatus(_ status: AVAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in self?.authorizationStatus = status }
    }

    private func publishCameraAvailability(_ available: Bool) {
        DispatchQueue.main.async { [weak self] in self?.cameraAvailable = available }
    }

    private func publishSessionRunning(_ running: Bool) {
        DispatchQueue.main.async { [weak self] in self?.isSessionRunning = running }
    }

    private func publishStatusMessage(_ message: String?) {
        DispatchQueue.main.async { [weak self] in self?.statusMessage = message }
    }

    @objc private func deviceWasDisconnected(_ notification: Notification) {
        stopSession()
        refreshCameraAvailability()
    }

    @objc private func deviceWasConnected(_ notification: Notification) {
        refreshCameraAvailability()
    }
}

extension WebcamManager: CameraSessionControlling {}
