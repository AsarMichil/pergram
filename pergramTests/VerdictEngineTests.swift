import Foundation
import Testing

@testable import pergram

struct VerdictEngineTests {
    let baseline = 1.00

    @Test func farBelowBaselineIsGood() {
        #expect(VerdictEngine.verdict(pricePer100g: 0.80, baselinePer100g: baseline) == .good)
    }

    @Test func exactlyAtGoodBoundaryIsGood() {
        #expect(VerdictEngine.verdict(pricePer100g: 1.05, baselinePer100g: baseline) == .good)
    }

    @Test func justAboveGoodBoundaryIsMeh() {
        #expect(VerdictEngine.verdict(pricePer100g: 1.06, baselinePer100g: baseline) == .meh)
    }

    @Test func exactlyAtMehBoundaryIsMeh() {
        #expect(VerdictEngine.verdict(pricePer100g: 1.25, baselinePer100g: baseline) == .meh)
    }

    @Test func justAboveMehBoundaryIsBad() {
        #expect(VerdictEngine.verdict(pricePer100g: 1.26, baselinePer100g: baseline) == .bad)
    }

    @Test func missingBaselineHasNoVerdict() {
        #expect(VerdictEngine.evaluate(pricePer100g: 1.10, baselinePer100g: nil) == nil)
    }

    @Test func presentBaselineEvaluates() {
        #expect(VerdictEngine.evaluate(pricePer100g: 0.90, baselinePer100g: baseline) == .good)
    }
}
