import Foundation
import Testing

@testable import pergram

struct ShelfTagFormatTests {
    @Test(arguments: [
        "$1.10 /100 g",
        "$ 1.10 /100 g",
        "1.10 $ /100 g",
        "1,10 $ /100 g",
        "1.10$ /100 g",
    ])
    func moneyRenderings(_ line: String) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: [line]))
        #expect(candidate.price == 1.10)
        #expect(candidate.amount == 100)
        #expect(candidate.unit == .gram)
    }

    @Test(arguments: [
        "$1.10/100 g",
        "$1.10/100g",
        "$1.10 / 100 g",
        "$1.10 /100g",
        "$1.10 par 100 g",
        "$1.10 per 100 g",
        "$1.10/100 gram",
        "$1.10/100 grammes",
        "$1.10/100 g.",
    ])
    func unitPhraseRenderings(_ line: String) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: [line]))
        #expect(candidate.price == 1.10)
        #expect(candidate.amount == 100)
        #expect(candidate.unit == .gram)
    }

    @Test(arguments: [
        (line: "$5.99/lb", unit: MeasureUnit.pound),
        (line: "$5.99 lb", unit: .pound),
        (line: "$5.99/lbs", unit: .pound),
        (line: "$5.99/livre", unit: .pound),
        (line: "$5.99 la livre", unit: .pound),
        (line: "$13.21/kg", unit: .kilogram),
        (line: "$13.21 le kg", unit: .kilogram),
        (line: "$13.21/kilogram", unit: .kilogram),
        (line: "$0.42/oz", unit: .ounce),
        (line: "$0.42/once", unit: .ounce),
        (line: "$0.50 each", unit: .each),
        (line: "$0.50/ea", unit: .each),
        (line: "$0.50 EACH", unit: .each),
        (line: "$0.50 per unit", unit: .each),
        (line: "$0.50/unit", unit: .each),
        (line: "$0.50 per item", unit: .each),
        (line: "$0.50/item", unit: .each),
        (line: "$0.50 chaque", unit: .each),
        (line: "$0.50 chacun", unit: .each),
        (line: "0,50 $ la pièce", unit: .each),
        (line: "0,50 $/pce", unit: .each),
        (line: "0,50 $ l'unité", unit: .each),
    ])
    func unitNouns(_ expected: (line: String, unit: MeasureUnit)) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: [expected.line]))
        #expect(candidate.unit == expected.unit)
        #expect(candidate.amount == 1)
    }

    @Test(arguments: [
        (weight: "455 g", amount: 455.0, unit: MeasureUnit.gram),
        (weight: "455g", amount: 455.0, unit: .gram),
        (weight: "1.716kg", amount: 1.716, unit: .kilogram),
        (weight: "1.716 kg", amount: 1.716, unit: .kilogram),
        (weight: "1,716 kg", amount: 1.716, unit: .kilogram),
        (weight: "0.5 kg", amount: 0.5, unit: .kilogram),
        (weight: "2 lb", amount: 2.0, unit: .pound),
        (weight: "907 g net", amount: 907.0, unit: .gram),
    ])
    func netWeightRenderings(_ expected: (weight: String, amount: Double, unit: MeasureUnit)) throws
    {
        let candidate = try #require(
            ShelfTagParser.candidate(from: ["$41.56", expected.weight]))
        #expect(candidate.price == 41.56)
        #expect(candidate.amount == expected.amount)
        #expect(candidate.unit == expected.unit)
    }

    @Test(arguments: [
        ["$5.99", "/lb"],
        ["$5.99", "/ lb"],
        ["5.99", "/lb"],
        ["$5.99", "lb"],
    ])
    func wrappedUnitPhrases(_ lines: [String]) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 5.99)
        #expect(candidate.unit == .pound)
    }

    @Test(arguments: [
        ["EVERYDAY LOW PRICE", "$4", "/lb"],
        ["EVERYDAY LOW PRICE", "$4/lb"],
        ["$4", "/LB"],
        ["$4 /lb"],
        ["$3LB"],
        ["$3 LB"],
    ])
    func wholeDollarProduceSigns(_ lines: [String]) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.amount == 1)
        #expect(candidate.unit == .pound)
    }

    @Test(arguments: [
        ["$4", "/lb"],
        ["$4", "/1b"],
        ["$4", "/ib"],
        ["$4", "/IB"],
        ["$3ib"],
    ])
    func mangledUnitTokens(_ lines: [String]) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.unit == .pound)
    }

    @Test func readsSuperscriptCentsFromTheHeadlineLine() throws {
        let lines = [
            ShelfTagLine("THIS WEEK ONLY", prominence: 0.05),
            ShelfTagLine("247", prominence: 0.22),
            ShelfTagLine("HONEYCRISP", prominence: 0.06),
            ShelfTagLine("APPLES", prominence: 0.06),
            ShelfTagLine("545", prominence: 0.10),
        ]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 2.47)
    }

    @Test func readsSuperscriptCentsPairedWithAUnitToken() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["545", "per kg"]))
        #expect(candidate.price == 5.45)
        #expect(candidate.amount == 1)
        #expect(candidate.unit == .kilogram)
    }

    @Test func aPunctuatedPriceBeatsASuperscriptCentsReading() throws {
        let lines = [
            ShelfTagLine("4011", prominence: 0.30),
            ShelfTagLine("$16.81", prominence: 0.08),
        ]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 16.81)
    }

    /// `545 / 247 = 2.206`, the pounds-per-kilogram ratio.
    @Test func readsAPoundAndKilogramPairWithoutAnyUnitToken() throws {
        let lines = ["THIS WEEK ONLY", "247", "HONEYCRISP", "APPLES", "545"]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 2.47)
        #expect(candidate.amount == 1)
        #expect(candidate.unit == .pound)
    }

    /// `545 / 241 = 2.26` and `545 / 298 = 1.83`, both outside the ratio.
    @Test func doesNotClaimAPairForNumbersOutsideTheRatio() throws {
        #expect(ShelfTagParser.candidate(from: ["241", "545"])?.unit == nil)
        #expect(ShelfTagParser.candidate(from: ["298", "545"])?.unit == nil)
    }

    @Test func aFrameWithNoHeadlineElectsNoPrice() {
        let lines = [
            ShelfTagLine("#41", prominence: 0.05),
            ShelfTagLine("148", prominence: 0.055),
        ]
        #expect(ShelfTagParser.candidate(from: lines) == nil)
    }

    @Test func bareDigitsAreNotAPriceWithoutProminence() {
        #expect(ShelfTagParser.candidate(from: ["THIS WEEK ONLY", "247", "APPLES"]) == nil)
    }

    @Test func aSuperscriptCentsShapeInsideAWeightDoesNotEatThePackSize() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$16.81", "1.528 kg"]))
        #expect(candidate.price == 16.81)
        #expect(candidate.amount == 1.528)
    }

    @Test(arguments: [
        (line: "2 for $5", count: 2.0, price: 5.0),
        (line: "2 FOR $5.00", count: 2.0, price: 5.0),
        (line: "2/$5.00", count: 2.0, price: 5.0),
        (line: "3 for $10", count: 3.0, price: 10.0),
        (line: "10 for $10.00", count: 10.0, price: 10.0),
        (line: "2 for 5.00", count: 2.0, price: 5.0),
        (line: "2 pour 5,00 $", count: 2.0, price: 5.0),
        (line: "2 @ $5.00", count: 2.0, price: 5.0),
    ])
    func multiBuyOffers(_ expected: (line: String, count: Double, price: Double)) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: [expected.line]))
        #expect(candidate.price == expected.price)
        #expect(candidate.amount == expected.count)
        #expect(candidate.unit == .each)

        let normalized = try #require(
            NormalizedPrice(money: expected.price, quantity: expected.count, unit: .each))
        #expect(normalized.canonical == expected.price / expected.count)
    }

    @Test(arguments: ["2/5", "2 for 5", "2 for 500", "SIZE 2/3", "AISLE 2 FOR YOU"])
    func doesNotReadAnUnpunctuatedPairAsAnOffer(_ line: String) {
        #expect(ShelfTagParser.candidate(from: [line])?.unit != .each)
    }

    @Test func theOfferPriceDoesNotResurfaceAsAPlainPrice() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["HONEYCRISP", "2 for $5.00"]))
        #expect(candidate.price == 5)
        #expect(candidate.amount == 2)
    }

    @Test(arguments: [
        "907 g",
        "1.528 kg",
        "12 x 355 ml",
        "PLU 4011",
        "STORE #1016",
        "0 2157678641562",
        "(01) (0218205000002 (3922) 001681",
        "EST. 215 103633472 SC9-T1 BEST BEFORE",
        "26- 037",
        "@17:42",
        "C 1-881-485-5111",
        "U145950",
        "110 MCARTHUR ROAD, OTTAWA, ON K1L 6PS",
        "TORONTO M4T 2S8, CANADA © 2020",
        "KEEP REFRIGERATED / GARDER AU FROID",
        "EXTRA LEAN GROUND BEEF",
        "PEACH PIE",
        "BIG BAG OF ORANGES",
    ])
    func noiseIsNeverAPrice(_ line: String) {
        #expect(ShelfTagParser.candidate(from: [line]) == nil)
    }
}

struct CrossValidatedPriceTests {
    @Test func twoPricesInTheRatioBeatAMisleadingAdjacency() throws {
        let lines = ["CRIPPS PINK APPLE", "$2.98", "$6.57.", "/LB"]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 2.98)
        #expect(candidate.unit == .pound)
    }

    @Test func theRatioHoldsWhicheverOrderTheyArriveIn() throws {
        for lines in [["$6.57", "$2.98"], ["$2.98", "$6.57"]] {
            let candidate = try #require(ShelfTagParser.candidate(from: lines))
            #expect(candidate.price == 2.98)
            #expect(candidate.amount == 1)
            #expect(candidate.unit == .pound)
        }
    }

    @Test func unrelatedPricesAreNotAPair() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$2.98", "$9.99"]))
        #expect(candidate.unit == nil)
    }

    @Test(arguments: ["/G", "/g", "g"])
    func aBarePerGramReadingIsATruncatedPerKilogram(_ token: String) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["APPLE", "$6.57", token]))
        #expect(candidate.price == 6.57)
        #expect(candidate.unit == nil)
    }

    @Test(arguments: ["$1.10 /100 g", "$1.10/100g", "$1.10 par 250 g"])
    func aQuantifiedGramPriceIsUntouched(_ line: String) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: [line]))
        #expect(candidate.unit == .gram)
    }
}

struct SplitSuperscriptTests {
    @Test func aStrayLargerGlyphDoesNotLockOutThePrice() throws {
        let lines = [
            ShelfTagLine("SALE", prominence: 0.05),
            ShelfTagLine("149", prominence: 0.18),
            ShelfTagLine("1", prominence: 0.24),
            ShelfTagLine("/LB", prominence: 0.04),
            ShelfTagLine("APPLE BIN GALA ORCH", prominence: 0.04),
            ShelfTagLine("15766", prominence: 0.03),
        ]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 1.49)
    }

    @Test func evenlySizedTextStillElectsNoPrice() {
        let lines = [
            ShelfTagLine("149", prominence: 0.05),
            ShelfTagLine("281", prominence: 0.052),
            ShelfTagLine("15766", prominence: 0.048),
        ]
        #expect(ShelfTagParser.candidate(from: lines) == nil)
    }
}
