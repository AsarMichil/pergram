import CoreGraphics
import Foundation
import Testing
import Vision

@testable import pergram

/// Recognition is pinned to English and French, and a Canadian tag cannot be printed in another
/// script — so a scalar outside Latin, Common and Inherited is Vision having guessed at the wrong
/// alphabet, which is the cue to look further down its ranked readings.
struct ScriptFilterTests {
    @Test(arguments: [
        "/lb", "$4", "$16.81", "1,528 kg", "EVERYDAY LOW PRICE", "247",
        "MEILLEUR AVANT", "unité", "pièce", "BOEUF HACHÉ EXTRA MAIGRE", "$4™", "99¢",
    ])
    func aTagCanBePrintedInThis(_ text: String) {
        #expect(ShelfTagRecognizer.isLatinScript(text))
    }

    /// Every one of these is a real reading of `/lb` from the device.
    @Test(arguments: ["Г ль", "ГЛЬ", "ЛЬ", "ЛІь", "Л1Ь", "/Іb", "рr нe", "Жорон"])
    func itCannotBePrintedInThis(_ text: String) {
        #expect(!ShelfTagRecognizer.isLatinScript(text))
    }
}

/// The single Cyrillic substitution kept after the ranked-candidate logs showed Vision offering no
/// Latin reading of `/lb` at any rank on some frames.
struct PoundRecoveryTests {
    /// Every one of these appeared in a ranked list from the device.
    @Test(arguments: ["ЛЬ", "Ль", "ль", "• ЛЬ", "•Ль"])
    func recoversThePoundToken(_ candidate: String) throws {
        let recovered = try #require(ShelfTagRecognizer.recoveringPound(candidate))
        #expect(recovered.contains("lb"))
        #expect(ShelfTagRecognizer.isLatinScript(recovered))
    }

    /// A partial rescue is just a differently wrong string, so these stay unread. Each keeps a glyph
    /// outside the pair, so substituting would leave the result still unprintable.
    @Test(arguments: ["гЛЬ", "г ЛЬ", "ґЛЬ", "ЛІЬ", "Жорон", "рr нe"])
    func leavesAnythingItCannotFullyRecover(_ candidate: String) {
        #expect(ShelfTagRecognizer.recoveringPound(candidate) == nil)
    }

    /// These do become printable, because every Cyrillic glyph in them is one of the pair — but the
    /// stroke between reads as a digit, and `l1b` is not a unit. Recovering them is harmless: the
    /// parser needs the two characters adjacent, so no pound is claimed either way.
    @Test(arguments: ["Л1Ь", "Л16"])
    func recoversToPrintableTextWithoutClaimingAUnit(_ candidate: String) throws {
        let recovered = try #require(ShelfTagRecognizer.recoveringPound(candidate))
        #expect(ShelfTagRecognizer.isLatinScript(recovered))
        #expect(ShelfTagParser.candidate(from: ["$4", recovered])?.unit == nil)
    }

    @Test(arguments: ["/lb", "$4", "unité", "EVERYDAY LOW PRICE"])
    func doesNotTouchTextThatWasAlreadyReadable(_ candidate: String) {
        #expect(ShelfTagRecognizer.recoveringPound(candidate) == nil)
    }

    /// The recovered token has to reach the parser as a pound, which is the whole point.
    @Test func aRecoveredTokenPairsWithThePriceAbove() throws {
        for token in ["lb", "• lb"] {
            let candidate = try #require(ShelfTagParser.candidate(from: ["$4", token]))
            #expect(candidate.price == 4)
            #expect(candidate.unit == .pound)
        }
    }
}

/// The region of interest has to match what the preview card shows, or the screen stops being an
/// honest account of what is being read.
struct VisibleRegionTests {
    /// The shipping shape: a 3:4 card over a 9:16 frame shows the full width and the middle three
    /// quarters of the height.
    @Test func aWideCardCropsTheHeight() {
        let region = ShelfTagRecognizer.visibleRegion(
            frameAspectRatio: 720.0 / 1280.0, previewAspectRatio: 3.0 / 4.0
        ).cgRect
        #expect(abs(region.width - 1) < 1e-9)
        #expect(abs(region.height - 0.75) < 1e-9)
        #expect(abs(region.minY - 0.125) < 1e-9)
        #expect(abs(region.minX) < 1e-9)
    }

    @Test func aNarrowCardCropsTheWidth() {
        let region = ShelfTagRecognizer.visibleRegion(
            frameAspectRatio: 3.0 / 4.0, previewAspectRatio: 9.0 / 16.0
        ).cgRect
        #expect(abs(region.height - 1) < 1e-9)
        #expect(abs(region.width - 0.75) < 1e-9)
        #expect(abs(region.minX - 0.125) < 1e-9)
    }

    @Test func amatchingCardCropsNothing() {
        let region = ShelfTagRecognizer.visibleRegion(
            frameAspectRatio: 0.75, previewAspectRatio: 0.75
        ).cgRect
        #expect(abs(region.width - 1) < 1e-9)
        #expect(abs(region.height - 1) < 1e-9)
    }

    /// Centred on both axes, which is what makes the bottom-left versus top-left origin difference
    /// between Vision and the preview layer cancel out.
    @Test(arguments: [0.4, 0.5625, 0.75, 1.0, 1.5])
    func theRegionIsAlwaysCentred(_ preview: Double) {
        let region = ShelfTagRecognizer.visibleRegion(
            frameAspectRatio: 0.5625, previewAspectRatio: preview
        ).cgRect
        #expect(abs(region.midX - 0.5) < 1e-9)
        #expect(abs(region.midY - 0.5) < 1e-9)
    }
}
