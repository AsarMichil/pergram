import Foundation
import Testing

@testable import pergram

/// The rule that decides when a reading is settled enough to fill the fields.
@MainActor
struct ScanDebounceTests {
    private let bare = ScanCandidate(price: 2.41)
    private let paired = ScanCandidate(price: 2.47, amount: 1, unit: .pound)

    @Test func nothingWinsOnASingleSighting() {
        #expect(ScanModel.winner(among: [bare]) == nil)
        #expect(ScanModel.winner(among: [bare, paired]) == nil)
    }

    @Test func theCommonestReadingWins() {
        let other = ScanCandidate(price: 9.99)
        #expect(ScanModel.winner(among: [bare, other, bare, other, bare]) == bare)
    }

    /// The case from the aisle: recognition alternated between `2.47` and `2.41`, and the misread
    /// happened to occur more often. The reading that also produced a unit is the better-evidenced
    /// one, so frequency does not get to decide.
    @Test func aReadingWithAUnitBeatsAMoreFrequentBareOne() {
        let recent = [bare, paired, bare, bare, paired, bare]
        #expect(ScanModel.winner(among: recent) == paired)
    }

    @Test func aLoneUnitReadingStillHasToRepeat() {
        #expect(ScanModel.winner(among: [bare, bare, paired]) == bare)
    }

    /// Straight from the aisle: the tag filled as `$4 per lb`, then the two frames that resolved
    /// the `/lb` aged out of the window and it refilled as a bare `$4`.
    @Test func aFilledUnitIsNotTradedForABareReadingOfTheSamePrice() {
        let bareFour = ScanCandidate(price: 4)
        let fourPerPound = ScanCandidate(price: 4, amount: 1, unit: .pound)
        #expect(ScanModel.isDowngrade(bareFour, from: fourPerPound))
        #expect(!ScanModel.isDowngrade(fourPerPound, from: bareFour))
    }

    @Test func aDifferentPriceIsNeverADowngrade() {
        let fourPerPound = ScanCandidate(price: 4, amount: 1, unit: .pound)
        #expect(!ScanModel.isDowngrade(ScanCandidate(price: 5), from: fourPerPound))
        #expect(!ScanModel.isDowngrade(ScanCandidate(price: 4), from: nil))
    }
}

/// Joining halves of a tag that no single frame could read whole.
@MainActor
struct CarriedUnitTests {
    private func reading(_ price: Double?, _ unit: ScanUnit? = nil) -> ShelfTagReading {
        ShelfTagReading(candidate: price.map { ScanCandidate(price: $0) }, unpairedUnit: unit)
    }
    private let perPound = ScanUnit(amount: 1, unit: .pound)

    /// The apple bin sign: `1⁴⁹ /LB`. One frame resolves `149` and loses the `/LB`, the next keeps
    /// the `/LB` and has no price. Neither frame is readable; the window is.
    @Test func aUnitFromOneFrameJoinsThePriceFromAnother() {
        let window = [reading(1.49), reading(nil, perPound), reading(1.49), reading(nil, perPound)]
        #expect(ScanModel.carriedUnit(in: window) == perPound)
    }

    /// Two prices means the tag prints two unit prices — `$2.98 /LB` and `$6.57 /KG` — and joining
    /// across frames would hand one of them the other's unit.
    @Test func twoPricesInTheWindowRefuseToCarry() {
        let window = [reading(2.98), reading(6.57), reading(nil, perPound)]
        #expect(ScanModel.carriedUnit(in: window) == nil)
    }

    @Test func twoDifferentUnitsInTheWindowRefuseToCarry() {
        let window = [
            reading(1.49), reading(nil, perPound),
            reading(nil, ScanUnit(amount: 1, unit: .kilogram)),
        ]
        #expect(ScanModel.carriedUnit(in: window) == nil)
    }

    @Test func aWindowWithNoUnitCarriesNothing() {
        #expect(ScanModel.carriedUnit(in: [reading(1.49), reading(1.49)]) == nil)
    }
}

/// The parser reports a per-unit token it could not attach to any price, so the window can.
struct UnpairedUnitTests {
    @Test func reportsAUnitTokenTheFrameCouldNotPair() {
        let reading = ShelfTagParser.reading(
            from: ["SALE", "49", "1", "/LB"].map { ShelfTagLine($0) })
        #expect(reading.candidate == nil)
        #expect(reading.unpairedUnit == ScanUnit(amount: 1, unit: .pound))
    }

    /// Nothing to report once the frame paired the unit itself.
    @Test func reportsNothingWhenTheUnitAlreadyBelongsToThePrice() {
        let reading = ShelfTagParser.reading(from: [ShelfTagLine("$5.99/lb")])
        #expect(reading.candidate?.unit == .pound)
        #expect(reading.unpairedUnit == nil)
    }

    /// A pack size is not a statement about how the tag prices, so it is not carried.
    @Test func aPackSizeIsNotAnUnpairedUnit() {
        let reading = ShelfTagParser.reading(from: [ShelfTagLine("907 g")])
        #expect(reading.unpairedUnit == nil)
    }
}
