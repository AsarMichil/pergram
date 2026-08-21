import Foundation
import Testing

@testable import pergram

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

    @Test func aReadingWithAUnitBeatsAMoreFrequentBareOne() {
        let recent = [bare, paired, bare, bare, paired, bare]
        #expect(ScanModel.winner(among: recent) == paired)
    }

    @Test func aLoneUnitReadingStillHasToRepeat() {
        #expect(ScanModel.winner(among: [bare, bare, paired]) == bare)
    }

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

@MainActor
struct CarriedUnitTests {
    private func reading(_ price: Double?, _ unit: ScanUnit? = nil) -> ShelfTagReading {
        ShelfTagReading(candidate: price.map { ScanCandidate(price: $0) }, unpairedUnit: unit)
    }
    private let perPound = ScanUnit(amount: 1, unit: .pound)

    @Test func aUnitFromOneFrameJoinsThePriceFromAnother() {
        let window = [reading(1.49), reading(nil, perPound), reading(1.49), reading(nil, perPound)]
        #expect(ScanModel.carriedUnit(in: window) == perPound)
    }

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

struct UnpairedUnitTests {
    @Test func reportsAUnitTokenTheFrameCouldNotPair() {
        let reading = ShelfTagParser.reading(
            from: ["SALE", "49", "1", "/LB"].map { ShelfTagLine($0) })
        #expect(reading.candidate == nil)
        #expect(reading.unpairedUnit == ScanUnit(amount: 1, unit: .pound))
    }

    @Test func reportsNothingWhenTheUnitAlreadyBelongsToThePrice() {
        let reading = ShelfTagParser.reading(from: [ShelfTagLine("$5.99/lb")])
        #expect(reading.candidate?.unit == .pound)
        #expect(reading.unpairedUnit == nil)
    }

    @Test func aPackSizeIsNotAnUnpairedUnit() {
        let reading = ShelfTagParser.reading(from: [ShelfTagLine("907 g")])
        #expect(reading.unpairedUnit == nil)
    }
}

@MainActor
struct WinnerDeterminismTests {
    private let cheap = ScanCandidate(price: 2.41)
    private let dear = ScanCandidate(price: 2.47)

    @Test func tiesGoToTheNewerReading() {
        #expect(ScanModel.winner(among: [cheap, cheap, dear, dear]) == dear)
        #expect(ScanModel.winner(among: [dear, dear, cheap, cheap]) == cheap)
    }

    @Test func theSameWindowAlwaysWinsTheSameWay() {
        let window = [cheap, dear, cheap, dear]
        let answers = Set((0..<200).map { _ in ScanModel.winner(among: window) })
        #expect(answers.count == 1)
    }
}
