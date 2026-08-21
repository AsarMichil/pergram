import Foundation
import Testing

@testable import pergram

struct ShelfTagParserTests {
    @Test func readsPer100gUnitPrice() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$1.10 /100 g"]))
        #expect(candidate.price == 1.10)
        #expect(candidate.amount == 100)
        #expect(candidate.unit == .gram)
    }

    @Test func readsPerPoundUnitPrice() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$5.99/lb"]))
        #expect(candidate.price == 5.99)
        #expect(candidate.amount == 1)
        #expect(candidate.unit == .pound)
    }

    @Test func readsPerKilogramUnitPrice() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$13.21 / kg"]))
        #expect(candidate.price == 13.21)
        #expect(candidate.unit == .kilogram)
    }

    @Test func readsEachAsCountDimension() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$0.50 each"]))
        #expect(candidate.price == 0.50)
        #expect(candidate.amount == 1)
        #expect(candidate.unit == .each)
    }

    @Test func readsBareNounUnitPriceWithoutSeparator() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$5.99 lb"]))
        #expect(candidate.price == 5.99)
        #expect(candidate.unit == .pound)
    }

    @Test func readsFrenchTrailingSignAndDecimalComma() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["1,10 $ / 100 g"]))
        #expect(candidate.price == 1.10)
        #expect(candidate.amount == 100)
        #expect(candidate.unit == .gram)
    }

    @Test func readsFrenchParSeparator() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["1,10 $ par 100 g"]))
        #expect(candidate.price == 1.10)
        #expect(candidate.amount == 100)
        #expect(candidate.unit == .gram)
    }

    @Test func readsFrenchLeKilo() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["11,00 $ le kg"]))
        #expect(candidate.price == 11.00)
        #expect(candidate.unit == .kilogram)
    }

    @Test func readsFrenchChaque() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["0,50 $ chaque"]))
        #expect(candidate.price == 0.50)
        #expect(candidate.unit == .each)
    }

    @Test func readsCentsSign() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["99¢ /100 g"]))
        #expect(abs(candidate.price - 0.99) < 1e-9)
        #expect(candidate.unit == .gram)
    }

    @Test func pairsPriceWithUnitPhraseOnTheNextLine() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$1.10", "/100 g"]))
        #expect(candidate.price == 1.10)
        #expect(candidate.amount == 100)
        #expect(candidate.unit == .gram)
    }

    @Test func pairsABigPriceWithThePerPoundLineBelowIt() throws {
        let lines = [
            ShelfTagLine("CHICKEN THIGHS", prominence: 0.04),
            ShelfTagLine("$5.99", prominence: 0.20),
            ShelfTagLine("/lb", prominence: 0.03),
        ]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 5.99)
        #expect(candidate.amount == 1)
        #expect(candidate.unit == .pound)
    }

    @Test func prefersUnitPriceOverShelfPrice() throws {
        let lines = ["CHICKEN THIGHS", "$5.49", "681 g", "$0.81 /100 g"]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 0.81)
        #expect(candidate.amount == 100)
        #expect(candidate.unit == .gram)
    }

    @Test func infersTheUnitPriceFromAPriceAndANetWeight() throws {
        let candidate = try #require(
            ShelfTagParser.candidate(from: ["CHICKEN THIGHS", "$5.45", "455 g"]))
        #expect(candidate.price == 5.45)
        #expect(candidate.amount == 455)
        #expect(candidate.unit == .gram)
    }

    @Test func infersTheUnitPriceFromAPriceAndNetWeightOnOneLine() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$5.45  455 g"]))
        #expect(candidate.price == 5.45)
        #expect(candidate.amount == 455)
        #expect(candidate.unit == .gram)
    }

    @Test func aPrintedUnitPriceBeatsAnInferredOne() throws {
        let lines = ["$8.99", "907 g", "$0.99 /100 g"]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 0.99)
        #expect(candidate.amount == 100)
    }

    @Test func leavesTheAmountBlankWhenTheTagShowsNoSizeAtAll() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["CHICKEN THIGHS", "$5.49"]))
        #expect(candidate.price == 5.49)
        #expect(candidate.amount == nil)
        #expect(candidate.unit == nil)
    }

    @Test func readsARandomWeightMeatLabel() throws {
        let lines = [
            "PC FE CHCKEN THCH BONELESS SKNLESS",
            "MEILLEUR AUANT", "BEST BEFORE", "$/kị", "NET WEISHT", "POIDS NET",
            "$16.81", "PRICE/PRIX", "11.0]", "1.528 kg",
            "(01) (0218205000002 (3922) 001681",
        ]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 16.81)
        #expect(candidate.amount == 1.528)
        #expect(candidate.unit == .kilogram)

        let normalized = try #require(
            NormalizedPrice(money: 16.81, quantity: 1.528, unit: .kilogram))
        #expect(abs(normalized.canonical - 1.10) < 0.01)
    }

    @Test func readsAClubPackLabelWithTheUnitAttachedToTheWeight() throws {
        let lines = [
            "EXTRA LEAN GROUND BEEF", "CLUB PACK", "BOEUF HACHÉ EXTRA MAIGRE",
            "PRIX-PRICE/Kg", "FOIDS/NET WETGHT", "1.716kg", "24.22", "TOTAL PRICE",
            "0 2157678641562", "$41.56",
        ]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 41.56)
        #expect(candidate.amount == 1.716)
        #expect(candidate.unit == .kilogram)
    }

    @Test func readsAUnitPriceWithNoSpaceBeforeTheUnit() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$1.10/100g"]))
        #expect(candidate.price == 1.10)
        #expect(candidate.amount == 100)
        #expect(candidate.unit == .gram)
    }

    @Test func readsAPackSizeWithNoSpaceBeforeTheUnit() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$5.45", "455g"]))
        #expect(candidate.amount == 455)
        #expect(candidate.unit == .gram)
    }

    @Test func doesNotReadAUnitOutOfTheEndOfAWord() {
        #expect(ShelfTagParser.candidate(from: ["PEACH PIE", "$4.99", "BIG BAG"])?.unit == nil)
    }

    @Test func readsADecimalNetWeightRatherThanItsFirstTwoDecimals() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$16.81", "1.528 kg"]))
        #expect(candidate.price == 16.81)
        #expect(candidate.amount == 1.528)
    }

    @Test func readsAFrenchDecimalNetWeight() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["16,81 $", "1,528 kg"]))
        #expect(candidate.price == 16.81)
        #expect(candidate.amount == 1.528)
        #expect(candidate.unit == .kilogram)
    }

    @Test func doesNotReadNetWeightAsAPrice() {
        #expect(ShelfTagParser.candidate(from: ["907 g", "1,36 kg", "12 x 355 ml"]) == nil)
    }

    @Test func doesNotReadABareNumberAsAPrice() {
        #expect(ShelfTagParser.candidate(from: ["4051", "PLU 4011"]) == nil)
    }

    @Test func doesNotReadItemNamesAsUnits() {
        #expect(ShelfTagParser.candidate(from: ["ORANGE JUICE", "LEAN GROUND BEEF"]) == nil)
    }

    @Test func readsAPerHundredMillilitreUnitPrice() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$1.17 /100 ml"]))
        #expect(candidate.price == 1.17)
        #expect(candidate.amount == 100)
        #expect(candidate.unit == .millilitre)
    }

    @Test func prefersTheVolumeUnitPriceOverTheShelfPrice() throws {
        let candidate = try #require(ShelfTagParser.candidate(from: ["$3.99", "$1.17 /100 ml"]))
        #expect(candidate.price == 1.17)
        #expect(candidate.unit == .millilitre)
    }

    @Test func picksTheMostProminentLineWhenTwoPricesCompete() throws {
        let lines = [
            ShelfTagLine("REG $6.99", prominence: 0.04),
            ShelfTagLine("$4.99", prominence: 0.22),
        ]
        let candidate = try #require(ShelfTagParser.candidate(from: lines))
        #expect(candidate.price == 4.99)
    }

    @Test func returnsNothingForEmptyInput() {
        #expect(ShelfTagParser.candidate(from: [String]()) == nil)
        #expect(ShelfTagParser.candidate(from: ["", "   "]) == nil)
    }
}
