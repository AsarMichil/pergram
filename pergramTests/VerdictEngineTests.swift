import Foundation
import Testing

@testable import pergram

struct VerdictEngineTests {
    let baseline = 1.00

    @Test func farBelowBaselineIsGood() {
        #expect(VerdictEngine.verdict(price: 0.80, baseline: baseline) == .good)
    }

    @Test func exactlyAtGoodBoundaryIsGood() {
        #expect(VerdictEngine.verdict(price: 1.05, baseline: baseline) == .good)
    }

    @Test func justAboveGoodBoundaryIsMeh() {
        #expect(VerdictEngine.verdict(price: 1.06, baseline: baseline) == .meh)
    }

    @Test func exactlyAtMehBoundaryIsMeh() {
        #expect(VerdictEngine.verdict(price: 1.25, baseline: baseline) == .meh)
    }

    @Test func justAboveMehBoundaryIsBad() {
        #expect(VerdictEngine.verdict(price: 1.26, baseline: baseline) == .bad)
    }

    /// The engine is scale-agnostic: the same bands apply to a count baseline in `$/each`.
    @Test func countBaselineUsesSameBands() {
        #expect(VerdictEngine.verdict(price: 0.40, baseline: 0.50) == .good)
        #expect(VerdictEngine.verdict(price: 0.60, baseline: 0.50) == .meh)
        #expect(VerdictEngine.verdict(price: 0.70, baseline: 0.50) == .bad)
    }
}
