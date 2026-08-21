import AVFoundation
import Foundation
import OSLog

/// Owns the capture session that feeds `ShelfTagRecognizer`.
///
/// `nonisolated` because session configuration blocks and must stay off the main actor;
/// `@unchecked Sendable` because every mutable property is touched only on `sessionQueue`. The one
/// shared reference is `session`, which `AVCaptureVideoPreviewLayer` is designed to read.
nonisolated final class CameraCapture: @unchecked Sendable {
    static var isAvailable: Bool { backCamera != nil }

    /// Beyond this, digital zoom is enlarging interpolated pixels — it stops helping the recognizer
    /// and starts hurting it.
    private static let maximumZoom: CGFloat = 5

    let session = AVCaptureSession()

    private let recognizer: ShelfTagRecognizer
    private let onRunning: @Sendable (Bool) -> Void
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.asarmichil.pergram.capture-session")
    private var isConfigured = false
    private var device: AVCaptureDevice?
    private var zoomAtGestureStart: CGFloat = 1
    private var observers: [any NSObjectProtocol] = []

    /// `onRunning` reports whether frames are actually flowing. Starting takes long enough to see,
    /// and a preview shown before then is a black rectangle the user reads as a hang.
    init(
        onReading: @escaping @Sendable (ShelfTagReading) -> Void,
        onRunning: @escaping @Sendable (Bool) -> Void
    ) {
        self.recognizer = ShelfTagRecognizer(onReading: onReading)
        self.onRunning = onRunning
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start() {
        sessionQueue.async { [self] in
            guard configureIfNeeded() else {
                onRunning(false)
                return
            }
            if session.isRunning {
                Log.camera.debug("start ignored, session already running")
            } else {
                recognizer.resume()
                let started = ContinuousClock.now
                session.startRunning()
                Log.camera.info(
                    "session running after \(started.duration(to: .now).milliseconds, format: .fixed(precision: 1), privacy: .public)ms"
                )
            }
            onRunning(true)
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            guard session.isRunning else {
                Log.camera.debug("stop ignored, session not running")
                return
            }
            // Hand no further frames to Vision before tearing down, so no buffer from the capture
            // pool is still checked out while AVFoundation dismantles the source behind it.
            recognizer.pause()
            session.stopRunning()
            Log.camera.info("session stopped")
        }
    }

    /// `point` is in the device's coordinate space, which only `AVCaptureVideoPreviewLayer` can
    /// convert a tap into.
    func focus(at point: CGPoint) {
        sessionQueue.async { [self] in
            guard let device else { return }
            configure(device) { device in
                if device.isFocusPointOfInterestSupported,
                    device.isFocusModeSupported(.autoFocus)
                {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported,
                    device.isExposureModeSupported(.continuousAutoExposure)
                {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
                // Without this a tap pins focus to that spot for the rest of the session.
                device.isSubjectAreaChangeMonitoringEnabled = true
            }
            Log.camera.debug(
                "focus at \(point.x, format: .fixed(precision: 2)), \(point.y, format: .fixed(precision: 2))"
            )
        }
    }

    /// Pinch reports scale relative to where the gesture started, so the starting factor is latched
    /// once rather than compounded on every update.
    func beginZoom() {
        sessionQueue.async { [self] in
            zoomAtGestureStart = device?.videoZoomFactor ?? 1
        }
    }

    func zoom(by scale: CGFloat) {
        sessionQueue.async { [self] in
            guard let device else { return }
            let ceiling = min(device.maxAvailableVideoZoomFactor, Self.maximumZoom)
            let target = min(
                max(zoomAtGestureStart * scale, device.minAvailableVideoZoomFactor), ceiling)
            configure(device) { $0.videoZoomFactor = target }
        }
    }

    private static var backCamera: AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }
        guard let device = Self.backCamera else {
            Log.camera.error("no back camera on this device")
            return false
        }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            Log.camera.error("camera input failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(recognizer, queue: recognizer.queue)
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            Log.camera.error("session rejected the camera input or video output")
            return false
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()

        self.device = device
        focusForShelfTags(device)
        observeSessionProblems()
        observeSubjectAreaChanges(device)
        isConfigured = true
        Log.camera.info(
            "configured \(device.localizedName, privacy: .public) at \(self.session.sessionPreset.rawValue, privacy: .public)"
        )
        return true
    }

    /// Shelf tags are read at arm's length, so restricting the focus range stops the lens hunting
    /// out to the far end of the aisle between frames.
    private func focusForShelfTags(_ device: AVCaptureDevice) {
        configure(device) { device in
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            device.isSubjectAreaChangeMonitoringEnabled = false
        }
    }

    private func configure(_ device: AVCaptureDevice, _ changes: (AVCaptureDevice) -> Void) {
        do {
            try device.lockForConfiguration()
        } catch {
            Log.camera.error("device lock failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        changes(device)
        device.unlockForConfiguration()
    }

    /// A material change in what the camera is pointed at is the cue that a tapped focus point has
    /// gone stale.
    private func observeSubjectAreaChanges(_ device: AVCaptureDevice) {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: device,
                queue: nil
            ) { [weak self] _ in
                self?.sessionQueue.async {
                    guard let self, let device = self.device else { return }
                    Log.camera.debug("subject area changed, back to continuous focus")
                    self.focusForShelfTags(device)
                }
            })
    }

    /// AVFoundation reports these out of band; without them a session that dies mid-scan just goes
    /// quiet.
    private func observeSessionProblems() {
        let center = NotificationCenter.default
        observers += [
            center.addObserver(
                forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
            ) { notification in
                let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
                Log.camera.error(
                    "runtime error: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            },
            center.addObserver(
                forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil
            ) { notification in
                let reason =
                    notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int ?? -1
                Log.camera.info("interrupted, reason \(reason, privacy: .public)")
            },
            center.addObserver(
                forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
            ) { _ in
                Log.camera.info("interruption ended")
            },
        ]
    }
}
