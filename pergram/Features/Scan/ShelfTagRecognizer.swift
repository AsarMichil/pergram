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
/// flag, which is atomic. The type
/// deliberately knows nothing about the capture session that feeds it — that keeps
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
    /// declaring its own, because the region of interest is derived from it — if the two drifted,
    /// the screen would quietly stop showing what is being read.
    static let previewAspectRatio: CGFloat = 3.0 / 4.0
    /// `.hd1280x720` delivered portrait.
    private static let frameAspectRatio: CGFloat = 720.0 / 1280.0

    /// The abbreviations a shelf tag prints that ordinary English and French would otherwise
    /// "correct" into words. Everything a verdict depends on is here.
    private static let unitVocabulary = [
        "lb", "lbs", "kg", "g", "oz", "ml", "ea", "pce",
        "livre", "livres", "chaque", "chacun", "unité", "pièce",
    ]

    /// The queue the capture output must deliver on: it is what serializes the state below.
    let queue = DispatchQueue(label: "com.asarmichil.pergram.capture-frames")

    private let onReading: @Sendable (ShelfTagReading) -> Void
    private let request = ShelfTagRecognizer.makeRequest()
    /// Atomic rather than queue-confined so that pausing never blocks its caller. It is read on the
    /// frame queue but written from the session queue during teardown, and a `sync` hop between two
    /// queues while the session is being dismantled is the kind of thing that deadlocks.
    private let isPaused = Atomic<Bool>(false)
    private var isRecognizing = false
    private var lastRun: ContinuousClock.Instant?

    init(onReading: @escaping @Sendable (ShelfTagReading) -> Void) {
        self.onReading = onReading
    }

    /// Stops handing frames to Vision. The store is sequentially consistent, so any frame the queue
    /// picks up after this returns sees it — which is the guarantee teardown needs, without blocking.
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

    /// The video output is left unrotated — physically rotating buffers costs a pipeline
    /// reconfiguration for nothing — so with the app locked to portrait the sensor's landscape
    /// frame reads as `.right`.
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
    /// down the list — the `/lb` that came back as `Г ль` is `/lb` again at rank 2.
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

    /// The one substitution the captures support: `ль` is `lb`.
    ///
    /// On a stylized `/lb` Vision sometimes offers no Latin reading at any rank, but `ЛЬ` appears
    /// somewhere in nearly every ranked list — it is the shape both glyphs agree on. Wider tables
    /// were tried and dropped, because per-character mapping is ambiguous: `Л` stands for `/l` in
    /// `ЛЬ` and for `/` in `ЛІЬ`, so no fixed table serves both.
    ///
    /// Returns `nil` unless the substitution makes the *whole* string printable. A partial rescue —
    /// `гЛЬ` becoming `гlb` — would only be a differently wrong string, and this is a last resort
    /// reached solely because Vision has already said it cannot read the line in a Latin script.
    static func recoveringPound(_ candidate: String) -> String? {
        let substituted = String(
            candidate.lowercased().map { Self.poundGlyphs[$0] ?? $0 })
        guard substituted != candidate.lowercased() else { return nil }
        return isLatinScript(substituted) ? substituted : nil
    }

    /// The device reads the same `/lb` as `ЛЬ`, as `$3лB` and as `Ль` — sometimes Vision picks a
    /// Cyrillic `ь` for the `b`, sometimes it gets the `b` right and only the `l` wrong. Both
    /// glyphs map the same way, so the pair is written out rather than the string `ль`.
    private static let poundGlyphs: [Character: Character] = ["л": "l", "ь": "b"]

    /// The part of the frame the preview card actually shows.
    ///
    /// `.resizeAspectFill` scales the frame to cover the card and crops the overflow, so a 3:4 card
    /// over a 9:16 frame displays the full width and the middle 75% of the height — the remaining
    /// eighth top and bottom is read today but never seen. Reading only what is shown makes the
    /// viewfinder honest, and costs a quarter less work per frame.
    ///
    /// The crop is centred, which is the reason this is safe to write without a device: Vision's
    /// origin is bottom-left and the preview's is top-left, and for a centred rect that difference
    /// cancels. Getting the axis wrong would produce the same numbers.
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
    /// combining marks that `unité` and `pièce` need. A tag cannot be written in anything else, so
    /// a scalar outside all three is Vision having guessed at the wrong alphabet.
    static func isLatinScript(_ text: String) -> Bool {
        text.firstMatch(of: nonLatinScalar) == nil
    }

    private static let nonLatinScalar =
        #/[^\p{Script=Latin}\p{Script=Common}\p{Script=Inherited}]/#

    /// Reading order — top to bottom, then left to right. Vision normalizes with the origin at the
    /// lower left, so a larger `maxY` sits higher up the tag. Tops are bucketed into rows first so
    /// the comparison stays a strict weak ordering, which a "within a tolerance" test would not be.
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
        // Correction is what makes the language list bite. Apple's wording is precise: disabling it
        // "returns the raw recognition results", and `recognitionLanguages` only "biases" — the bias
        // is applied by the correction pass. With correction off there is no language model between
        // the glyph classifier and the output, which is why a stylized `/lb` came back as Cyrillic
        // even with the languages pinned and auto-detection off.
        request.usesLanguageCorrection = true
        // Correction can only give precedence to words it is told about, and it ignores this list
        // entirely when correction is off. These are the tokens a verdict depends on.
        request.customWords = Self.unitVocabulary
        // Left to detect for itself, Vision reads a stylized `/lb` as Cyrillic — `Л1Ь`, `/Іb` — and
        // a shelf tag gives it far too little text to detect a language from. The languages are
        // known, so say so.
        request.automaticallyDetectsLanguage = false
        // The `/lb` beside a big price is tiny: on a tag filling half the frame it falls under the
        // 1/32 default and Vision never reports it at all.
        request.minimumTextHeightFraction = 0.01
        request.regionOfInterest = visibleRegion()

        // Setting `recognitionLanguages` is not proof it took: an identifier Vision does not support
        // is ignored rather than rejected, which would let any alphabet back in. Log what was asked
        // for against what this revision actually supports.
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
        // Printed so a bad crop is diagnosable from the log alone. For a 3:4 card over a 9:16 frame
        // this must read x 0.00 y 0.13 w 1.00 h 0.75 — full width, middle three quarters. A frame
        // that shows text in the preview but logs no observations means these numbers are wrong.
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
