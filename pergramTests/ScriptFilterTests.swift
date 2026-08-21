import CoreGraphics
import Foundation
import Testing
import Vision

@testable import pergram

struct ScriptFilterTests {
    @Test(arguments: [
        "/lb", "$4", "$16.81", "1,528 kg", "EVERYDAY LOW PRICE", "247",
        "MEILLEUR AVANT", "unité", "pièce", "BOEUF HACHÉ EXTRA MAIGRE", "$4™", "99¢",
    ])
    func aTagCanBePrintedInThis(_ text: String) {
        #expect(ShelfTagRecognizer.isLatinScript(text))
    }

    @Test(arguments: ["Г ль", "ГЛЬ", "ЛЬ", "ЛІь", "Л1Ь", "/Іb", "рr нe", "Жорон"])
    func itCannotBePrintedInThis(_ text: String) {
        #expect(!ShelfTagRecognizer.isLatinScript(text))
    }
}

struct PoundRecoveryTests {
    @Test(arguments: ["ЛЬ", "Ль", "ль", "• ЛЬ", "•Ль"])
    func recoversThePoundToken(_ candidate: String) throws {
        let recovered = try #require(ShelfTagRecognizer.recoveringPound(candidate))
        #expect(recovered.contains("lb"))
        #expect(ShelfTagRecognizer.isLatinScript(recovered))
    }

    @Test(arguments: ["гЛЬ", "г ЛЬ", "ґЛЬ", "ЛІЬ", "Жорон", "рr нe"])
    func leavesAnythingItCannotFullyRecover(_ candidate: String) {
        #expect(ShelfTagRecognizer.recoveringPound(candidate) == nil)
    }

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

    @Test func aRecoveredTokenPairsWithThePriceAbove() throws {
        for token in ["lb", "• lb"] {
            let candidate = try #require(ShelfTagParser.candidate(from: ["$4", token]))
            #expect(candidate.price == 4)
            #expect(candidate.unit == .pound)
        }
    }
}

struct VisibleRegionTests {
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

    @Test func aMatchingCardCropsNothing() {
        let region = ShelfTagRecognizer.visibleRegion(
            frameAspectRatio: 0.75, previewAspectRatio: 0.75
        ).cgRect
        #expect(abs(region.width - 1) < 1e-9)
        #expect(abs(region.height - 1) < 1e-9)
    }

    /// Centred on both axes is what makes Vision's bottom-left origin and the preview layer's
    /// top-left origin cancel out.
    @Test(arguments: [0.4, 0.5625, 0.75, 1.0, 1.5])
    func theRegionIsAlwaysCentred(_ preview: Double) {
        let region = ShelfTagRecognizer.visibleRegion(
            frameAspectRatio: 0.5625, previewAspectRatio: preview
        ).cgRect
        #expect(abs(region.midX - 0.5) < 1e-9)
        #expect(abs(region.midY - 0.5) < 1e-9)
    }
}
