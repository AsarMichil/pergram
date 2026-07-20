import Foundation
import Testing

@testable import pergram

struct UnitGraphTests {
    let graph = UnitGraph.standard

    @Test func poundToGram() {
        #expect(graph.convert(1, from: .pound, to: .gram) == 453.592)
    }

    @Test func ounceToGram() {
        #expect(graph.convert(1, from: .ounce, to: .gram) == 28.3495)
    }

    @Test func kilogramToGram() {
        #expect(graph.convert(2, from: .kilogram, to: .gram) == 2000)
    }

    @Test func gramToPer100Grams() {
        #expect(graph.convert(250, from: .gram, to: .per100Grams) == 2.5)
    }

    @Test func multiHopPoundToKilogram() throws {
        let value = try #require(graph.convert(1, from: .pound, to: .kilogram))
        #expect(abs(value - 0.453592) < 1e-9)
    }

    @Test func roundTripReturnsOriginal() throws {
        let toGram = try #require(graph.conversionFactor(from: .pound, to: .gram))
        let backToPound = try #require(graph.conversionFactor(from: .gram, to: .pound))
        #expect(abs(toGram * backToPound - 1) < 1e-12)
    }

    @Test func sameUnitIsIdentity() {
        #expect(graph.convert(42, from: .gram, to: .gram) == 42)
    }

    @Test func eachIsUnreachable() {
        #expect(graph.convert(1, from: .each, to: .gram) == nil)
        #expect(graph.convert(1, from: .gram, to: .each) == nil)
    }
}
