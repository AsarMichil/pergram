import Foundation
import Testing

@testable import pergram

struct VolumeTests {
    @Test(arguments: [
        (unit: MeasureUnit.millilitre, quantity: 100.0, canonical: 1.17),
        (unit: .millilitre, quantity: 250.0, canonical: 0.468),
        (unit: .litre, quantity: 1.0, canonical: 0.117),
        (unit: .per100Millilitres, quantity: 1.0, canonical: 1.17),
    ])
    func normalizesToPer100Millilitres(
        _ expected: (unit: MeasureUnit, quantity: Double, canonical: Double)
    ) throws {
        let price = try #require(
            NormalizedPrice(money: 1.17, quantity: expected.quantity, unit: expected.unit))
        #expect(price.dimension == .volume)
        #expect(abs(price.canonical - expected.canonical) < 1e-9)
    }

    @Test(arguments: [MeasureUnit.gram, .kilogram, .pound, .ounce, .per100Grams, .each])
    func volumeDoesNotConvertIntoAnyOtherDimension(_ other: MeasureUnit) {
        #expect(UnitGraph.standard.conversionFactor(from: .millilitre, to: other) == nil)
        #expect(UnitGraph.standard.conversionFactor(from: other, to: .millilitre) == nil)
    }

    @Test func litresAndMillilitresConvert() throws {
        let factor = try #require(
            UnitGraph.standard.conversionFactor(from: .litre, to: .millilitre))
        #expect(factor == 1000)
    }

    @Test func everyUnitBelongsToExactlyOneDimension() {
        for unit in MeasureUnit.allCases {
            let canonical = MeasureUnit.canonicalUnit(for: unit.dimension)
            #expect(canonical.dimension == unit.dimension)
        }
    }

    @Test(arguments: PriceDimension.allCases)
    func everyDimensionHasDisplayUnits(_ dimension: PriceDimension) {
        let units = PriceDisplay.units(for: dimension)
        #expect(!units.isEmpty)
        #expect(units.allSatisfy { $0.dimension == dimension })
        #expect(units.contains(MeasureUnit.canonicalUnit(for: dimension)))
    }

    @Test func cyclingTheDisplayUnitStaysWithinTheDimension() {
        var unit = MeasureUnit.per100Millilitres
        for _ in 0..<4 {
            unit = PriceDisplay.next(after: unit, in: .volume)
            #expect(unit.dimension == .volume)
        }
    }

    @Test func displaysPerLitre() {
        let price = NormalizedPrice(dimension: .volume, canonical: 1.17)
        #expect(abs(PriceDisplay.value(price, in: .litre) - 11.70) < 1e-9)
        #expect(abs(PriceDisplay.value(price, in: .per100Millilitres) - 1.17) < 1e-9)
    }

    @Test func aBarePerMillilitreReadingIsRejected() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["JUICE", "$3.99", "/mL"]))
        #expect(candidate.price == 3.99)
        #expect(candidate.unit == nil)
    }

    @Test(arguments: [
        (line: "$1.17/100 ml", unit: MeasureUnit.millilitre, amount: 100.0),
        (line: "1,17 $ par 100 ml", unit: .millilitre, amount: 100.0),
        (line: "$2.49/L", unit: .litre, amount: 1.0),
        (line: "$2.49 le litre", unit: .litre, amount: 1.0),
        (line: "$2.49/litre", unit: .litre, amount: 1.0),
    ])
    func readsVolumeUnitPrices(_ expected: (line: String, unit: MeasureUnit, amount: Double)) throws
    {
        let candidate = try #require(ShelfTagParser.candidate(from: [expected.line]))
        #expect(candidate.unit == expected.unit)
        #expect(candidate.amount == expected.amount)
    }

    @Test func infersAUnitPriceFromABottleSize() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["JUICE", "$3.99", "1.89 L"]))
        #expect(candidate.price == 3.99)
        #expect(abs((candidate.amount ?? 0) - 1.89) < 1e-9)
        #expect(candidate.unit == .litre)
    }

    @Test func aPostalCodeIsNotABottle() throws {
        let lines = ["130 MCARTHUR ROAD, OTTAWA, ON K1L 6PS", "$16.81", "1.528 kg"]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.amount == 1.528)
        #expect(candidate.unit == .kilogram)
    }
}

struct PackSizeGuardTests {
    @Test(arguments: [
        (line: "$5.45 g", price: 5.45), (line: "$5.45 kg", price: 5.45),
        (line: "$1.89 L", price: 1.89), (line: "$1.89 ml", price: 1.89),
    ])
    func aCurrencyFormattedPriceIsNeverItsOwnQuantity(
        _ expected: (line: String, price: Double)
    )
        throws
    {
        let candidate = try #require(ShelfTagParser.candidate(from: ["ITEM", expected.line]))
        #expect(abs(candidate.price - expected.price) < 1e-9)
        #expect(candidate.amount != expected.price)
    }

    @Test(arguments: [
        (size: "1.89 L", amount: 1.89, unit: MeasureUnit.litre),
        (size: "2.63L", amount: 2.63, unit: .litre),
        (size: "946 ml", amount: 946.0, unit: .millilitre),
        (size: "1.716kg", amount: 1.716, unit: .kilogram),
        (size: "455 g", amount: 455.0, unit: .gram),
    ])
    func anUnpricedSizeIsAPackSize(
        _ expected: (size: String, amount: Double, unit: MeasureUnit)
    )
        throws
    {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$3.99", expected.size]))
        #expect(candidate.price == 3.99)
        #expect(abs((candidate.amount ?? 0) - expected.amount) < 1e-9)
        #expect(candidate.unit == expected.unit)
    }
}
