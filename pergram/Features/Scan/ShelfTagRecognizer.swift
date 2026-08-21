import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import OSLog
import Synchronization
import Vision

/// Turns camera frames into `ShelfTagReading`s with Vision's on-device text recognition.
///
/// `nonisolated` because both the sample-buffer callback and Vision belong off the main actor;
/// `@unchecked Sendable` because `queue` below serializes every mutable property except the paused
/// flag, which is atomic. Knowing nothing about the capture session that feeds it is what keeps
/// `AVCaptureVideoDataOutput`'s strong hold on its delegate from closing a retain cycle.
nonisolated final class ShelfTagRecognizer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable
{
    /// Frames arrive at 30 fps; recognizing a handful per second is enough to feel instant and
    /// leaves the camera pipeline room to breathe.
    private static let interval = Duration.milliseconds(200)
    private static let minimumConfidence: Float = 0.3
    /// Two lines land in the same row when their tops agree to within a fortieth of the frame.
    private static let rowsPerFrame = 40.0
    /// How far down Vision's ranked readings to look for one in an alphabet a tag can be printed in.
    private static let candidateDepth = 5

    /// The shape of the preview card. `ScanModeView` takes its aspect ratio from here rather than
    /// declaring its own, because the region of interest is derived from it.
    static let previewAspectRatio: CGFloat = 3.0 / 4.0
    /// `.hd1280x720` delivered portrait.
    private static let frameAspectRatio: CGFloat = 720.0 / 1280.0

    /// The abbreviations a shelf tag prints that ordinary English and French would otherwise
    /// "correct" into words.
    private static let unitVocabulary = [
        "lb", "lbs", "kg", "g", "oz", "ml", "ea", "pce",
        "livre", "livres", "chaque", "chacun", "unité", "pièce",
    ]

    /// The queue the capture output must deliver on: it is what serializes the state below.
    let queue = DispatchQueue(label: "com.asarmichil.pergram.capture-frames")

    private let onReading: @Sendable (ShelfTagReading) -> Void
    private let request = ShelfTagRecognizer.makeRequest()
    /// Atomic rather than queue-confined: it is read on the frame queue but written from the
    /// session queue during teardown, and a `sync` hop between the two while the session is being
    /// dismantled is the kind of thing that deadlocks.
    private let isPaused = Atomic<Bool>(false)
    private var isRecognizing = false
    private var lastRun: ContinuousClock.Instant?

    init(onReading: @escaping @Sendable (ShelfTagReading) -> Void) {
        self.onReading = onReading
    }

    /// Stops handing frames to Vision. The store is sequentially consistent, so any frame the queue
    /// picks up after this returns sees it.
    func pause() {
        isPaused.store(true, ordering: .sequentiallyConsistent)
    }

    func resume() {
        isPaused.store(false, ordering: .sequentiallyConsistent)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isPaused.load(ordering: .sequentiallyConsistent), !isRecognizing,
            let pixelBuffer = sampleBuffer.imageBuffer
        else { return }
        let now = ContinuousClock.now
        if let lastRun, now - lastRun < Self.interval { return }
        lastRun = now
        isRecognizing = true

        Task { [self] in
            let reading = await reading(in: pixelBuffer)
            queue.async { self.isRecognizing = false }
            if let reading { onReading(reading) }
        }
    }

    /// The video output is left unrotated, so with the app locked to portrait the sensor's
    /// landscape frame reads as `.right`.
    private func reading(in pixelBuffer: CVPixelBuffer) async -> ShelfTagReading? {
        let started = ContinuousClock.now
        let observations: [RecognizedTextObservation]
        do {
            observations = try await request.perform(on: pixelBuffer, orientation: .right)
        } catch {
            Log.vision.error("recognition failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        let lines =
            observations
            .filter { $0.confidence >= Self.minimumConfidence }
            .sorted { Self.readingKey($0) < Self.readingKey($1) }
            .map { ShelfTagLine(Self.reading(of: $0), prominence: Double($0.boundingBox.height)) }
        let reading = ShelfTagParser.reading(from: lines)

        Log.vision.debug(
            """
            \(observations.count) observations, \(lines.count) kept, \
            \(started.duration(to: .now).milliseconds, format: .fixed(precision: 1), privacy: .public)ms \
            → \(String(describing: reading), privacy: .public)
            """
        )
        Log.vision.debug(
            "lines: \(lines.map(\.text).joined(separator: " | "), privacy: .public)")
        return reading
    }

    /// Vision ranks several readings per line and `transcript` is only the first. When the top one
    /// contains a script the tag cannot be written in, the right answer is usually a place or two
    /// down the list.
    ///
    /// Falls back to the top candidate rather than dropping the line: an unreadable line is still
    /// evidence of where the readable ones sit.
    private static func reading(of observation: RecognizedTextObservation) -> String {
        let candidates = observation.topCandidates(Self.candidateDepth).map(\.string)
        guard let top = candidates.first else { return observation.transcript }
        guard let clean = candidates.first(where: isLatinScript) else {
            if let recovered = candidates.lazy.compactMap(recoveringPound).first {
                Log.vision.debug(
                    "recovered '\(recovered, privacy: .public)' from '\(top, privacy: .public)'")
                return recovered
            }
            Log.vision.debug(
                "no printable reading: \(candidates.joined(separator: " · "), privacy: .public)")
            return top
        }
        if clean != top {
            let rank = (candidates.firstIndex(of: clean) ?? 0) + 1
            Log.vision.debug(
                "preferred rank \(rank, privacy: .public) '\(clean, privacy: .public)' over '\(top, privacy: .public)'"
            )
        }
        return clean
    }

    /// The one substitution worth making when Vision offers no Latin reading of a line at any rank:
    /// `ль` is `lb`. Per-character mapping is ambiguous beyond this pair, so `nil` unless the
    /// substitution makes the *whole* string printable — a partial rescue would only be a
    /// differently wrong string.
    static func recoveringPound(_ candidate: String) -> String? {
        let substituted = String(
            candidate.lowercased().map { Self.poundGlyphs[$0] ?? $0 })
        guard substituted != candidate.lowercased() else { return nil }
        return isLatinScript(substituted) ? substituted : nil
    }

    /// Vision picks the Cyrillic `ь` for the `b` and the `л` for the `l` independently, so the two
    /// map one character at a time rather than as the string `ль`.
    private static let poundGlyphs: [Character: Character] = ["л": "l", "ь": "b"]

    /// The part of the frame the preview card actually shows: `.resizeAspectFill` scales the frame
    /// to cover the card and crops the overflow, so reading only this keeps the viewfinder honest.
    ///
    /// The crop is centred, so Vision's bottom-left origin and the preview's top-left cancel —
    /// getting the axis wrong would produce the same numbers.
    static func visibleRegion(
        frameAspectRatio frame: CGFloat = ShelfTagRecognizer.frameAspectRatio,
        previewAspectRatio preview: CGFloat = ShelfTagRecognizer.previewAspectRatio
    ) -> NormalizedRect {
        let width = preview > frame ? 1 : preview / frame
        let height = preview > frame ? frame / preview : 1
        return NormalizedRect(
            x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
    }

    /// Latin covers the letters, Common the digits, currency and punctuation, Inherited the
    /// combining marks that `unité` and `pièce` need. A scalar outside all three is Vision having
    /// guessed at the wrong alphabet.
    static func isLatinScript(_ text: String) -> Bool {
        text.firstMatch(of: nonLatinScalar) == nil
    }

    private static let nonLatinScalar =
        #/[^\p{Script=Latin}\p{Script=Common}\p{Script=Inherited}]/#

    /// Reading order — top to bottom, then left to right. Vision's origin is the lower left, so a
    /// larger `maxY` sits higher up the tag. Tops are bucketed into rows so that the comparison
    /// stays a strict weak ordering, which a "within a tolerance" test would not be.
    private static func readingKey(_ observation: RecognizedTextObservation) -> (Double, Double) {
        let box = observation.boundingBox.cgRect
        return (((1 - box.maxY) * Self.rowsPerFrame).rounded(), box.minX)
    }

    private static func makeRequest() -> RecognizeTextRequest {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [
            Locale.Language(identifier: "en-US"), Locale.Language(identifier: "fr-FR"),
        ]
        // Correction is what makes the language list bite: `recognitionLanguages` only biases, and
        // the bias is applied by the correction pass. With correction off there is no language model
        // between the glyph classifier and the output at all.
        request.usesLanguageCorrection = true
        // Correction can only give precedence to words it is told about, and ignores this list
        // entirely when correction is off.
        request.customWords = Self.unitVocabulary
        // A shelf tag gives Vision far too little text to detect a language from, and left to
        // itself it reads a stylized `/lb` as Cyrillic. The languages are known, so say so.
        request.automaticallyDetectsLanguage = false
        // The `/lb` beside a big price is tiny: on a tag filling half the frame it falls under the
        // 1/32 default and Vision never reports it at all.
        request.minimumTextHeightFraction = 0.01
        request.regionOfInterest = visibleRegion()

        // An identifier Vision does not support is ignored rather than rejected, which would let
        // any alphabet back in — so log what was asked for against what this revision supports.
        let supported = Set(request.supportedRecognitionLanguages.map(\.minimalIdentifier))
        let requested = request.recognitionLanguages.map(\.minimalIdentifier)
        Log.vision.info(
            """
            languages \(requested.joined(separator: " "), privacy: .public) \
            (unsupported: \(requested.filter { !supported.contains($0) }.joined(separator: " "), privacy: .public)), \
            auto-detect \(request.automaticallyDetectsLanguage, privacy: .public), \
            correction \(request.usesLanguageCorrection, privacy: .public)
            """
        )
        // Printed so a bad crop is diagnosable from the log alone: text visible in the preview with
        // no observations logged means these numbers are wrong.
        let region = request.regionOfInterest.cgRect
        Log.vision.info(
            """
            region of interest x \(region.minX, format: .fixed(precision: 2), privacy: .public) \
            y \(region.minY, format: .fixed(precision: 2), privacy: .public) \
            w \(region.width, format: .fixed(precision: 2), privacy: .public) \
            h \(region.height, format: .fixed(precision: 2), privacy: .public) \
            (frame \(Self.frameAspectRatio, format: .fixed(precision: 3), privacy: .public), \
            preview \(Self.previewAspectRatio, format: .fixed(precision: 3), privacy: .public))
            """
        )
        return request
    }
}
