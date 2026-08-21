import AVFoundation
import Foundation
import OSLog

/// Drives the Scan screen: camera permission, session lifecycle, and the debounce that decides
/// when a reading is steady enough to fill the Check fields.
@MainActor
@Observable
final class ScanModel {
    enum Status: Equatable {
        case idle
        /// The session has been asked to run but frames are not flowing yet. Showing the preview
        /// during this reads as a hang, because there is nothing in it to see.
        case starting
        case scanning
        case denied
        case unavailable
    }

    /// A vote over the last few frames rather than a run of two: recognition does not fail cleanly
    /// on a stylized price, it alternates between two plausible readings.
    private static let voteWindow = 6
    private static let agreeingFramesNeeded = 2

    private(set) var status: Status = .idle
    private(set) var filledTick = 0
    private(set) var hasFilled = false

    var onCandidate: ((ScanCandidate) -> Void)?

    private var capture: CameraCapture?
    private var recent: [ShelfTagReading] = []
    private var filled: ScanCandidate?

    var session: AVCaptureSession? { capture?.session }

    func start() {
        guard CameraCapture.isAvailable else {
            Log.scan.info("no camera available")
            status = .unavailable
            return
        }
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        Log.scan.info("start, authorization \(authorization.rawValue, privacy: .public)")
        switch authorization {
        case .authorized:
            beginScanning()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                Log.scan.info("access \(granted ? "granted" : "denied", privacy: .public)")
                if granted {
                    beginScanning()
                } else {
                    status = .denied
                }
            }
        default:
            status = .denied
        }
    }

    /// Leaving Scan clears what was read, so pointing at the same tag again fills again instead of
    /// being suppressed as a repeat.
    func stop() {
        capture?.stop()
        recent.removeAll()
        filled = nil
        hasFilled = false
        if status == .scanning || status == .starting { status = .idle }
    }

    func focus(at devicePoint: CGPoint) {
        capture?.focus(at: devicePoint)
    }

    func beginZoom() {
        capture?.beginZoom()
    }

    func zoom(by scale: CGFloat) {
        capture?.zoom(by: scale)
    }

    private func beginScanning() {
        let capture =
            capture
            ?? CameraCapture(
                onReading: { [weak self] reading in
                    guard let self else { return }
                    Task { @MainActor in self.receive(reading) }
                },
                onRunning: { [weak self] isRunning in
                    guard let self else { return }
                    Task { @MainActor in self.status = isRunning ? .scanning : .unavailable }
                }
            )
        self.capture = capture
        capture.start()
        status = .starting
    }

    private func receive(_ reading: ShelfTagReading) {
        guard status == .scanning || status == .starting else { return }
        recent.append(reading)
        if recent.count > Self.voteWindow { recent.removeFirst() }
        guard var winner = Self.winner(among: recent.compactMap(\.candidate)) else { return }
        if winner.unit == nil, let carried = Self.carriedUnit(in: recent) {
            winner = ScanCandidate(
                price: winner.price, amount: carried.amount, unit: carried.unit)
        }
        guard winner != filled, !Self.isDowngrade(winner, from: filled) else { return }
        filled = winner
        hasFilled = true
        filledTick += 1
        Log.scan.info("filled from tag: \(String(describing: winner), privacy: .public)")
        onCandidate?(winner)
    }

    /// A tag can be legible across the window and illegible in every single frame of it: one frame
    /// resolves the price and loses the `/LB`, the next keeps the `/LB` and has no price.
    ///
    /// Joining them is safe only where the window is unambiguous about both halves. Two distinct
    /// prices means the tag prints two unit prices, and pairing across frames would then hand one of
    /// them the other's unit.
    static func carriedUnit(in recent: [ShelfTagReading]) -> ScanUnit? {
        let prices = Set(recent.compactMap { $0.candidate?.price })
        let units = Set(recent.compactMap(\.unpairedUnit))
        guard prices.count == 1, units.count == 1 else { return nil }
        return units.first
    }

    /// Never trade a reading with a unit for one without it at the same price. The frames that
    /// resolved the unit are the rare ones, so they age out while bare readings keep arriving, and
    /// the fill would walk backwards a second after landing on the better answer.
    static func isDowngrade(_ candidate: ScanCandidate, from filled: ScanCandidate?) -> Bool {
        guard let filled else { return false }
        return candidate.price == filled.price && candidate.unit == nil && filled.unit != nil
    }

    /// A reading that carries a unit beats one that does not, however often the bare one repeats:
    /// it had to satisfy more of the tag to be produced at all, so it is the better-evidenced one.
    static func winner(among recent: [ScanCandidate]) -> ScanCandidate? {
        var counts: [ScanCandidate: Int] = [:]
        for candidate in recent { counts[candidate, default: 0] += 1 }

        // Walked newest-first over the window rather than over the counts, because a dictionary
        // iterates in hash order, which is seeded per launch: two readings tied on evidence would
        // fill differently from one run to the next. Ties go to the newer reading.
        var winner: (candidate: ScanCandidate, count: Int)?
        for candidate in recent.reversed() {
            let count = counts[candidate, default: 0]
            guard count >= agreeingFramesNeeded else { continue }
            guard let held = winner else {
                winner = (candidate, count)
                continue
            }
            let carriesUnit = candidate.unit != nil
            if carriesUnit != (held.candidate.unit != nil) {
                if carriesUnit { winner = (candidate, count) }
            } else if count > held.count {
                winner = (candidate, count)
            }
        }
        return winner?.candidate
    }
}
