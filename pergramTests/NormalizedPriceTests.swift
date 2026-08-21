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

    @Test func countDoesNotConvertIntoMass() {
        #expect(UnitGraph.standard.conversionFactor(from: .each, to: .gram) == nil)
        #expect(UnitGraph.standard.conversionFactor(from: .gram, to: .each) == nil)
    }
}

@MainActor
struct ScannedEntryTests {
    @Test(arguments: [
        (amount: 1.528, text: "1.528"), (amount: 1.716, text: "1.716"),
        (amount: 455.0, text: "455"), (amount: 1.89, text: "1.89"), (amount: 1.5, text: "1.5"),
    ])
    func aScannedWeightKeepsItsPrecision(_ expected: (amount: Double, text: String)) {
        let viewModel = CheckViewModel()
        viewModel.applyScannedEntry(
            ScanCandidate(price: 16.81, amount: expected.amount, unit: .kilogram))
        #expect(viewModel.amountText == expected.text)
        #expect(viewModel.amountValue == expected.amount)
    }

    @Test func aScannedPriceKeepsTwoDecimals() {
        let viewModel = CheckViewModel()
        viewModel.applyScannedEntry(ScanCandidate(price: 1.10, amount: 100, unit: .gram))
        #expect(viewModel.priceText == "1.10")
    }
}
