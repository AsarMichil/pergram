import Foundation
import Testing

@testable import pergram

/// Whole `lines:` payloads from the `vision` log, split on the same `" | "` the log writes, so a
/// captured label pastes in unedited, OCR misreads and all. A `nil` price means the frame should
/// read as nothing.
struct ShelfTagFixtureTests {
    struct Fixture {
        let name: String
        let lines: String
        let price: Double?
        let amount: Double?
        let unit: MeasureUnit?
    }

    @Test(arguments: [
        Fixture(
            name:
                "Loblaws random-weight chicken thigh — `$/kg` misread as `$/kị`, `11.00` as `11.0]`",
            lines: """
                •Loblaws | 130 MCARTHUR RORD. OTTALR, ON K1L EPS | STORE#1016 | \
                PC FE CHCKEN THCH BONELESS SKNLESS | PC SB HRUT DE CUISSE DE POULET DESOSSE | \
                SANS PERU FC | MEILLEUR AUANT | BEST BEFORE | $/kị | NET WEISHT | POIDS NET | \
                $16.81 | PRICE/PRIX | 11.0] | 1.528 kg | KEEP REFRIGERATED / GARDER AU FROID | \
                (01) (0218205000002 (3922) 001681 | 313
                """,
            price: 16.81, amount: 1.528, unit: .kilogram
        ),
        Fixture(
            name: "Butcher's Choice club pack — net weight with the unit attached",
            lines: """
                "BUTCHER'S CHOICE• | LE CHOIX DU BOUCHER: | LOBLAW'S INC. | \
                TORONTO MAT 2S8, CANADA & 2020 | C 1-881-485-5111 | U145950 | \
                EXTRA LEAN GROUND BEEF | CLUB PACK | BOEUF HACHÉ EXTRA MAIGRE | PRQUET CLUB | \
                EST. 215 103633472 SC9-T1 BEST BEFORE | 26- 037 | @17:42 | MEILLEUR AVANT | \
                PRIX-PRICE/Kg | FOIDS/NET WETGHT | 1.716kg | 24.22 | TOTAL PRICE | \
                0 2157678641562 | $41.56
                """,
            price: 41.56, amount: 1.716, unit: .kilogram
        ),
        Fixture(
            name: "Butcher's Choice, second frame — `1.715kg` and `PRIX-PRICE/KS` misreads",
            lines: """
                EXTRA LENH GROUND BEEF | CLUB PACK | BOEUF HACHÉ EXTRR MAIGRE | PAQUET CLUB | \
                1S1 290 1016514/2 909-11 | 1 87 | 24.22 | 1.715kg | ISAIE / 1A9H19 | $41.56
                """,
            price: 41.56, amount: 1.715, unit: .kilogram
        ),
        Fixture(
            name: "Honeycrisp produce sign — superscript cents, and `per kg` misread as `per ke`",
            lines: """
                THIS WEEK ONLY | 247 | HONEYCRISP | APPLES | EXTRA FANCY GRADE | \
                ONTARIO, CANADA | WAS | 298 | 545 | per ke
                """,
            price: 2.47, amount: 1, unit: .pound
        ),
        Fixture(
            name: "A frame with no tag in it — chrome, fragments and nothing priced",
            lines: """
                Thu Aug | tag• | HOT | DEALS | ANS PE | (5922) | S#* be | 420. | • I 33 | 982 | \
                SAN | HOT DEALS | First | Cale | utranke | HOT | •DEALS | 037 | 82 | I STN | \
                DEAS | NAT 258 | 42 | NETL | on!
                """,
            price: nil, amount: nil, unit: nil
        ),
    ])
    func capturedLabel(_ fixture: Fixture) throws {
        let lines = fixture.lines.components(separatedBy: " | ")
        let candidate = ShelfTagParser.candidate(from: lines)

        guard let price = fixture.price else {
            #expect(candidate == nil, "\(fixture.name) should read as nothing")
            return
        }
        let read = try #require(candidate, "\(fixture.name) should have been read")
        #expect(read.price == price)
        #expect(read.amount == fixture.amount)
        #expect(read.unit == fixture.unit)
    }
}
