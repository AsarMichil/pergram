import Foundation
import Testing

@testable import pergram

/// The number formats a Canadian tag can print, enumerated rather than discovered.
///
/// Every bug this suite exists to catch was found the same way: a real label printed a number in a
/// shape the parser had not been taught, one shape at a time. None of them were OCR failures —
/// Vision read `1.716kg` perfectly, the parser threw it away. The formats are a small, enumerable
/// space, so they are enumerated here instead of discovered in the aisle.
struct ShelfTagFormatTests {
    /// Every way of writing the money in "$1.10 per 100 g".
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

    /// Every way of writing the "per 100 g" half. The unspaced forms are the ones real labels use
    /// and the ones a word boundary before the unit silently rejects.
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

    /// Each unit noun the token table claims to know, in English and French.
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

    /// Net weights, which a label prints in more shapes than a unit price: attached units, three
    /// decimals, and a French decimal comma.
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

    /// The unit price arrives on the line below the price as often as beside it.
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

    /// The produce-sign format: a whole-dollar price in huge type with a tiny `/lb` beside it. The
    /// price carries no cents at all, and the `/lb` is where recognition is weakest.
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

    /// How Vision renders a small `/lb`: `l`, `i` and `1` are one vertical stroke in a tag font, so
    /// the pound token has to accept all three.
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

    /// Produce signs raise the cents, and recognition returns the digits run together: `$2⁴⁷` comes
    /// back as `247`. Nothing in the digits says it is money, so it takes the biggest line on the
    /// tag or an adjacent unit token to license the reading.
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

    /// The reinterpretation is a rescue, never an override: a punctuated price on the same tag wins,
    /// even when the bare digits are printed larger.
    @Test func aPunctuatedPriceBeatsASuperscriptCentsReading() throws {
        let lines = [
            ShelfTagLine("4011", prominence: 0.30),
            ShelfTagLine("$16.81", prominence: 0.08),
        ]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 16.81)
    }

    /// A produce sign prints both prices. `545 / 247 = 2.206`, which is pounds per kilogram, so the
    /// two numbers vouch for each other — and for the pound, without either unit token being legible.
    @Test func readsAPoundAndKilogramPairWithoutAnyUnitToken() throws {
        let lines = ["THIS WEEK ONLY", "247", "HONEYCRISP", "APPLES", "545"]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 2.47)
        #expect(candidate.amount == 1)
        #expect(candidate.unit == .pound)
    }

    /// `241` is the misread; `545 / 2.41 = 2.26` is outside the ratio, so no pair is claimed.
    @Test func doesNotClaimAPairForNumbersOutsideTheRatio() throws {
        #expect(ShelfTagParser.candidate(from: ["241", "545"])?.unit == nil)
        #expect(ShelfTagParser.candidate(from: ["298", "545"])?.unit == nil)
    }

    /// A frame holding two scraps of similar-sized text must not elect one of them the price.
    @Test func aFrameWithNoHeadlineElectsNoPrice() {
        let lines = [
            ShelfTagLine("#41", prominence: 0.05),
            ShelfTagLine("148", prominence: 0.055),
        ]
        #expect(ShelfTagParser.candidate(from: lines) == nil)
    }

    /// Without prominence there is nothing to license the reading, so bare digits stay noise.
    @Test func bareDigitsAreNotAPriceWithoutProminence() {
        #expect(ShelfTagParser.candidate(from: ["THIS WEEK ONLY", "247", "APPLES"]) == nil)
    }

    /// `1.528 kg` contains `528`, which is a superscript-cents shape. It must not cancel the weight
    /// it sits inside.
    @Test func aSuperscriptCentsShapeInsideAWeightDoesNotEatThePackSize() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$16.81", "1.528 kg"]))
        #expect(candidate.price == 16.81)
        #expect(candidate.amount == 1.528)
    }

    /// Multi-buy: the count qualifying the price sits *before* it, so read as a plain price the
    /// answer is wrong by the count. `2 for $5` is $2.50 each, not $5.
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

    /// The price has to be punctuated, or "for" and "/" are far too common to key off.
    @Test(arguments: ["2/5", "2 for 5", "2 for 500", "SIZE 2/3", "AISLE 2 FOR YOU"])
    func doesNotReadAnUnpunctuatedPairAsAnOffer(_ line: String) {
        #expect(ShelfTagParser.candidate(from: [line])?.unit != .each)
    }

    /// The offer's price must not also stand as a price on its own.
    @Test func theOfferPriceDoesNotResurfaceAsAPlainPrice() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["HONEYCRISP", "2 for $5.00"]))
        #expect(candidate.price == 5)
        #expect(candidate.amount == 2)
    }

    /// Real noise from real captures: barcodes, PLU codes, phone numbers, addresses, weights and
    /// timestamps. Not one of them carries a currency symbol, so not one of them is a price.
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

/// A tag that prints both `$2.98 /LB` and `$6.57 /KG` gives the parser two prices and two unit
/// tokens, and reading order does not reliably keep each price beside its own token.
struct CrossValidatedPriceTests {
    /// Straight from the aisle. Reading order delivered `$2.98 | $6.57. | /LB`, and pairing the
    /// trailing price of one line with the token opening the next filled `$6.57 per pound` — the
    /// per-kilogram price wearing the per-pound label, 2.2× too expensive.
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

    /// Prices that are not in the ratio must not be claimed as a pair.
    @Test func unrelatedPricesAreNotAPair() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$2.98", "$9.99"]))
        #expect(candidate.unit == nil)
    }

    /// `g` is a suffix of `kg`, so a dropped character turns one real unit into another — the only
    /// misread that swaps a valid reading for a different valid reading. No tag prices by the single
    /// gram, so a per-gram reading with no quantity is a truncated per-kilogram one. The price was
    /// read correctly and survives.
    @Test(arguments: ["/G", "/g", "g"])
    func aBarePerGramReadingIsATruncatedPerKilogram(_ token: String) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["APPLE", "$6.57", token]))
        #expect(candidate.price == 6.57)
        #expect(candidate.unit == nil)
    }

    /// A gram unit that carries its own quantity is how tags really write it, and is untouched.
    @Test(arguments: ["$1.10 /100 g", "$1.10/100g", "$1.10 par 250 g"])
    func aQuantifiedGramPriceIsUntouched(_ line: String) throws {
        let candidate = try #require(ShelfTagParser.candidate(from: [line]))
        #expect(candidate.unit == .gram)
    }

}

/// A tag that sets the dollars larger than the cents — `1⁴⁹` — gets read in pieces: sometimes as
/// `149`, sometimes as a huge `1` and a raised `49`, often with both in the same frame.
struct SplitSuperscriptTests {
    /// From the aisle. `149` and `/LB` were both in this frame and it still read as nothing: the
    /// stray `1` is taller than the `149`, so demanding the price be the largest line locked it out.
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

    /// A frame of evenly sized text still elects nothing, which is the guard the threshold replaced
    /// "must be the largest" without weakening.
    @Test func evenlySizedTextStillElectsNoPrice() {
        let lines = [
            ShelfTagLine("149", prominence: 0.05),
            ShelfTagLine("281", prominence: 0.052),
            ShelfTagLine("15766", prominence: 0.048),
        ]
        #expect(ShelfTagParser.candidate(from: lines) == nil)
    }
}
