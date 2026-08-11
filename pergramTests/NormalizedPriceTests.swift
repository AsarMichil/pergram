import Foundation
import Testing

@testable import pergram

struct NormalizedPriceTests {
    @Test func massNormalizesToPer100g() throws {
        let price = try #require(NormalizedPrice(money: 5.00, quantity: 500, unit: .gram))
        #expect(price.dimension == .mass)
        #expect(abs(price.canonical - 1.00) < 0.0001)
    }

    @Test func countNormalizesToPerEach() throws {
        let price = try #require(NormalizedPrice(money: 4.99, quantity: 12, unit: .each))
        #expect(price.dimension == .count)
        #expect(abs(price.canonical - (4.99 / 12)) < 0.0001)
    }

    @Test func nonPositiveInputsAreNil() {
        #expect(NormalizedPrice(money: 0, quantity: 12, unit: .each) == nil)
        #expect(NormalizedPrice(money: 4.99, quantity: 0, unit: .each) == nil)
        #expect(NormalizedPrice(money: -1, quantity: 500, unit: .gram) == nil)
    }

    @Test func eachIsCountEveryOtherUnitIsMass() {
        #expect(MeasureUnit.each.dimension == .count)
        for unit in [MeasureUnit.gram, .kilogram, .pound, .ounce, .per100Grams] {
            #expect(unit.dimension == .mass)
        }
    }

    @Test func canonicalUnitPerDimension() {
        #expect(MeasureUnit.canonicalUnit(for: .mass) == .per100Grams)
        #expect(MeasureUnit.canonicalUnit(for: .count) == .each)
    }

    /// Count carries no mass, so it must never resolve a conversion into the mass graph.
    @Test func countDoesNotConvertIntoMass() {
        #expect(UnitGraph.standard.conversionFactor(from: .each, to: .gram) == nil)
        #expect(UnitGraph.standard.conversionFactor(from: .gram, to: .each) == nil)
    }
}
