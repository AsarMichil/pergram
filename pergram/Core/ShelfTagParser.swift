import Foundation

/// One recognized line of a shelf tag.
nonisolated struct ShelfTagLine: Equatable, Sendable {
    let text: String
    /// How tall this line is printed, as a fraction of the frame.
    let prominence: Double

    init(_ text: String, prominence: Double = 0) {
        self.text = text
        self.prominence = prominence
    }
}

/// A shelf tag read into the Check screen's three fields.
///
/// `amount` and `unit` are `nil` when only a bare price was legible.
nonisolated struct ScanCandidate: Hashable, Sendable {
    let price: Double
    let amount: Double?
    let unit: MeasureUnit?

    init(price: Double, amount: Double? = nil, unit: MeasureUnit? = nil) {
        self.price = price
        self.amount = amount
        self.unit = unit
    }
}

/// A unit a tag printed that no price on the same frame could be attached to.
nonisolated struct ScanUnit: Hashable, Sendable {
    let amount: Double
    let unit: MeasureUnit
}

/// Everything one frame yielded. Frames of the same tag disagree about which half they can read, so
/// the unpaired unit is reported rather than discarded, for a caller watching several frames.
nonisolated struct ShelfTagReading: Hashable, Sendable {
    let candidate: ScanCandidate?
    let unpairedUnit: ScanUnit?
}

/// Reads Canadian shelf-tag text into a `ScanCandidate`.
///
/// Canadian tags legally print a unit price, in English or French, so the token table is
/// bilingual: `/100 g` · `par 100 g` · `/kg` · `le kg` · `/lb` · `chaque` · `each`, with currency
/// written `$1.10`, `1,10 $` (decimal comma, trailing sign) or `99¢`.
nonisolated enum ShelfTagParser {
    static func candidate(from lines: [String]) -> ScanCandidate? {
        candidate(from: lines.map { ShelfTagLine($0) })
    }

    /// `lines` must be in **reading order**, top to bottom: a tag prints its unit price as `$5.99`
    /// above `/lb` as often as beside it, and only reading order makes those two adjacent.
    static func candidate(from lines: [ShelfTagLine]) -> ScanCandidate? {
        reading(from: lines).candidate
    }

    /// As `candidate(from:)`, but also reporting a per-unit token the frame could not attach to any
    /// price. Only reported when the candidate has no unit of its own.
    static func reading(from lines: [ShelfTagLine]) -> ShelfTagReading {
        let parsed = lines.map(ParsedLine.init(line:))
        // On the text alone `247` is indistinguishable from a PLU code, so the strict reading runs
        // first: reinterpreting it as cents can rescue a blank, never overrule a punctuated price.
        let best =
            best(in: parsed, readingImplicitCents: false)
            ?? best(in: parsed, readingImplicitCents: true)
        let candidate = best.map { withPackSize($0, in: parsed) }
        return ShelfTagReading(
            candidate: candidate,
            unpairedUnit: candidate?.unit == nil ? unpairedUnit(in: parsed) : nil
        )
    }

    /// A per-unit token standing on its own. The separator is required: a pack size says nothing
    /// about how the tag prices, but `/lb` and `per kg` say it outright.
    private static func unpairedUnit(in lines: [ParsedLine]) -> ScanUnit? {
        lines.lazy.compactMap(\.separatorPhrase).first
    }

    private static func best(in parsed: [ParsedLine], readingImplicitCents: Bool) -> Ranked? {
        let headline = headlineThreshold(in: parsed)
        var best: Ranked? = poundKilogramPair(in: parsed, implicitCents: readingImplicitCents)
        var consumed: Set<MoneyKey> = []

        // Multi-buy first, because it is the one shape where the number that qualifies the price
        // sits *before* it, and the money it consumes must not resurface as a price of its own.
        if !readingImplicitCents {
            for (index, line) in parsed.enumerated() {
                for offer in line.multiBuys {
                    consumed.insert(MoneyKey(line: index, start: offer.money.range.lowerBound))
                    best = better(
                        Ranked(
                            candidate: ScanCandidate(
                                price: offer.money.value, amount: offer.count, unit: .each),
                            isUnitPrice: true,
                            isCurrencyFormatted: offer.money.isCurrencyFormatted,
                            prominence: line.prominence,
                            value: offer.money.value
                        ), best)
                }
            }
        }

        for (index, line) in parsed.enumerated() {
            for money in line.money
            where money.isImplicitCents == readingImplicitCents
                && !consumed.contains(MoneyKey(line: index, start: money.range.lowerBound))
            {
                guard let phrase = line.phrase(after: money), isUnitPrice(money, phrase)
                else { continue }
                consumed.insert(MoneyKey(line: index, start: money.range.lowerBound))
                best = better(rank(money, phrase, prominence: line.prominence), best)
            }
        }

        // A tag prints "$5.99" and "/lb" on separate lines as readily as on one.
        for index in parsed.indices.dropFirst() {
            guard let phrase = parsed[index].openingPhrase,
                let money = parsed[index - 1].trailingMoney,
                money.isImplicitCents == readingImplicitCents,
                isUnitPrice(money, phrase)
            else { continue }
            let key = MoneyKey(line: index - 1, start: money.range.lowerBound)
            guard !consumed.contains(key) else { continue }
            consumed.insert(key)
            best = better(rank(money, phrase, prominence: parsed[index - 1].prominence), best)
        }

        for (index, line) in parsed.enumerated() {
            for money in line.money
            where money.isImplicitCents == readingImplicitCents
                && isBarePrice(money, prominence: line.prominence, headline: headline)
                && !consumed.contains(MoneyKey(line: index, start: money.range.lowerBound))
            {
                let ranked = Ranked(
                    candidate: ScanCandidate(price: money.value),
                    isUnitPrice: false,
                    isCurrencyFormatted: money.isCurrencyFormatted,
                    prominence: line.prominence,
                    value: money.value
                )
                best = better(ranked, best)
            }
        }

        return best
    }

    /// How tall an unpunctuated digit run must be printed to read as a price: half again a typical
    /// line on this tag. Relative, so it calibrates to how close the shot was framed, and `nil` when
    /// nothing stands out at all — which stops a frame of evenly sized scraps electing one of them.
    ///
    /// A threshold rather than the largest line, because a tag setting the dollars larger than the
    /// cents gets the `1` of `1⁴⁹` read as its own observation, taller than the `149` beside it.
    private static func headlineThreshold(in lines: [ParsedLine]) -> Double? {
        let prominences = lines.map(\.prominence).sorted()
        guard let largest = prominences.last, largest > 0 else { return nil }
        let middle = prominences.count / 2
        let median =
            prominences.count.isMultiple(of: 2)
            ? (prominences[middle - 1] + prominences[middle]) / 2
            : prominences[middle]
        let threshold = median * 1.5
        return largest >= threshold ? threshold : nil
    }

    private static func isBarePrice(
        _ money: MoneyMatch, prominence: Double, headline: Double?
    ) -> Bool {
        if money.isCurrencyFormatted { return true }
        guard let headline else { return false }
        return prominence >= headline
    }

    /// A produce sign nearly always prints both prices — `$2⁴⁷ /lb` above `$5⁴⁵ per kg`. Two numbers
    /// standing in the pound-to-kilogram ratio confirm each other: they are prices rather than
    /// product codes, and the smaller one is per pound, whether or not either unit token was legible.
    private static func poundKilogramPair(in lines: [ParsedLine], implicitCents: Bool) -> Ranked? {
        guard let ratio = UnitGraph.standard.conversionFactor(from: .kilogram, to: .pound) else {
            return nil
        }
        let candidates = lines.flatMap { line in
            line.money.filter { $0.isImplicitCents == implicitCents }
                .map { (money: $0, line: line) }
        }
        var best: Ranked?
        for pound in candidates {
            for kilogram in candidates
            where abs(kilogram.money.value / pound.money.value - ratio) <= ratio
                * Self.ratioTolerance
            {
                best = better(
                    Ranked(
                        candidate: ScanCandidate(price: pound.money.value, amount: 1, unit: .pound),
                        isCrossValidated: true,
                        isUnitPrice: true,
                        isCurrencyFormatted: pound.money.isCurrencyFormatted,
                        prominence: pound.line.prominence,
                        value: pound.money.value
                    ), best)
            }
        }
        return best
    }

    /// Signs round the converted price to the cent, so the two never divide out exactly.
    private static let ratioTolerance = 0.015

    /// A price and a net weight with no unit price anywhere — `$5.45` over `455 g` — is itself a
    /// unit price. Applied last and only to a bare price, so a printed unit price beats inference.
    private static func withPackSize(_ best: Ranked, in lines: [ParsedLine]) -> ScanCandidate {
        guard !best.isUnitPrice, let pack = lines.lazy.compactMap(\.packSize).first else {
            return best.candidate
        }
        return ScanCandidate(price: best.candidate.price, amount: pack.amount, unit: pack.unit)
    }

    /// A price sitting next to a unit phrase reads as a unit price when either side says so: an
    /// explicit separator (`/100 g`), or a currency symbol against a bare noun (`$5.99 lb`). A
    /// quantity with no separator is a pack size instead — `$5.49 681 g` is a price beside a net
    /// weight. An unpunctuated digit run needs the separator specifically, since nothing in `545`
    /// distinguishes a price beside `per kg` from a net weight beside `g`.
    private static func isUnitPrice(_ money: MoneyMatch, _ phrase: UnitPhrase) -> Bool {
        if isTruncatedBaseUnit(phrase) { return false }
        if money.isImplicitCents { return phrase.hasSeparator }
        return phrase.hasSeparator || (money.isCurrencyFormatted && !phrase.hasExplicitQuantity)
    }

    /// `g` is a suffix of `kg` and `l` of `ml`, so a dropped character turns one real unit into
    /// another — the only misread that swaps a valid reading for a different valid one. No tag
    /// prices by the single gram or millilitre, so `$6.57 /G` is not $657 per 100 g.
    private static func isTruncatedBaseUnit(_ phrase: UnitPhrase) -> Bool {
        Self.baseUnits.contains(phrase.unit) && !phrase.hasExplicitQuantity
    }

    private static let baseUnits: Set<MeasureUnit> = [.gram, .millilitre]

    private static func rank(
        _ money: MoneyMatch, _ phrase: UnitPhrase, prominence: Double
    ) -> Ranked {
        Ranked(
            candidate: ScanCandidate(
                price: money.value, amount: phrase.amount, unit: phrase.unit),
            isUnitPrice: true,
            isCurrencyFormatted: money.isCurrencyFormatted,
            prominence: prominence,
            value: money.value
        )
    }

    private static func better(_ candidate: Ranked?, _ incumbent: Ranked?) -> Ranked? {
        guard let candidate else { return incumbent }
        guard let incumbent else { return candidate }
        return candidate.outranks(incumbent) ? candidate : incumbent
    }

    private struct Ranked {
        let candidate: ScanCandidate
        /// Two prices on the tag agreeing arithmetically, which beats a price merely sitting next to
        /// a unit token: adjacency is a guess about layout and the ratio is not.
        var isCrossValidated = false
        let isUnitPrice: Bool
        let isCurrencyFormatted: Bool
        let prominence: Double
        let value: Double

        func outranks(_ other: Ranked) -> Bool {
            if isCrossValidated != other.isCrossValidated { return isCrossValidated }
            if isUnitPrice != other.isUnitPrice { return isUnitPrice }
            if isCurrencyFormatted != other.isCurrencyFormatted { return isCurrencyFormatted }
            if prominence != other.prominence { return prominence > other.prominence }
            return value > other.value
        }
    }

    private struct MoneyKey: Hashable {
        let line: Int
        let start: String.Index
    }
}

// MARK: - Line scanning

private nonisolated struct MoneyMatch {
    let value: Double
    let range: Range<String.Index>
    let isCurrencyFormatted: Bool
    /// A bare digit run read as dollars-and-cents: `247` for `$2⁴⁷`. A last resort, because on the
    /// text alone it is indistinguishable from a PLU code.
    let isImplicitCents: Bool
}

private nonisolated struct UnitPhrase {
    let range: Range<String.Index>
    let amount: Double
    let hasExplicitQuantity: Bool
    let hasSeparator: Bool
    let unit: MeasureUnit
}

private nonisolated struct ParsedLine {
    let text: String
    let prominence: Double
    let money: [MoneyMatch]

    init(line: ShelfTagLine) {
        self.text = ParsedLine.normalized(line.text)
        self.prominence = line.prominence
        self.money = ParsedLine.money(in: self.text)
    }

    /// `2 for $5`, `2/$5.00`, `3 pour 10,00 $` — a count, then a price for that many. The price has
    /// to be punctuated, or `2/5` is a date and "for" is everywhere in ordinary text.
    var multiBuys: [(count: Double, money: MoneyMatch)] {
        text.matches(of: ParsedLine.multiBuyPattern).compactMap { offer in
            guard let count = Double(offer.output.quantity), count >= 2,
                let money = money.first(where: {
                    !$0.isImplicitCents
                        && $0.range.lowerBound >= offer.range.upperBound
                        && text.distance(from: offer.range.upperBound, to: $0.range.lowerBound) <= 1
                })
            else { return nil }
            return (count, money)
        }
    }

    /// The first per-unit token on the line, whether or not any price could be attached to it.
    var separatorPhrase: ScanUnit? {
        for phrase in ParsedLine.phrases(in: text) {
            guard phrase.hasSeparator else { continue }
            return ScanUnit(amount: phrase.amount, unit: phrase.unit)
        }
        return nil
    }

    /// A net weight or pack size: a quantity and a unit with no per-separator.
    var packSize: (amount: Double, unit: MeasureUnit)? {
        for phrase in ParsedLine.phrases(in: text) {
            // Only a *currency-formatted* price blocks a pack size, since the symbol is the one
            // thing that tells a price from a quantity: `$5.45 g` must not read 5.45 as a weight,
            // while `1.89 L` is a bottle whose size is spelled exactly like a price.
            guard phrase.hasExplicitQuantity, !phrase.hasSeparator,
                !money.contains(where: {
                    $0.isCurrencyFormatted && $0.range.overlaps(phrase.range)
                })
            else { continue }
            return (phrase.amount, phrase.unit)
        }
        return nil
    }

    /// Searched from the end of the price rather than across the whole line, so the phrase's
    /// optional quantity cannot swallow the price's own decimals: `$0.50 each` is not "50 each".
    func phrase(after money: MoneyMatch) -> UnitPhrase? {
        ParsedLine.phrase(atStartOf: text[money.range.upperBound...], within: 2)
    }

    var openingPhrase: UnitPhrase? {
        ParsedLine.phrase(atStartOf: text[...], within: 1)
    }

    var trailingMoney: MoneyMatch? {
        guard let match = money.last,
            text.distance(from: match.range.upperBound, to: text.endIndex) <= 1
        else { return nil }
        return match
    }

    private static func normalized(_ raw: String) -> String {
        String(
            raw.lowercased().map { character in
                switch character {
                case "\u{00a0}", "\u{202f}": return " "
                case "\u{2044}", "\u{2215}": return "/"
                default: return character
                }
            })
    }

    /// The spaces around the currency sign are bound to the sign itself, so a match never eats the
    /// space separating a price from the unit phrase after it. The `(?!\d)` guarding the cents stops
    /// a three-decimal net weight — `1.528 kg` — reading as the price `1.52`.
    private static let moneyPattern =
        #/(?:(?<lead>[$¢])[ ]?)?(?<whole>\d{1,4})(?:[.,](?<fraction>\d{1,2})(?!\d))?(?:[ ]?(?<trail>[$¢]))?/#

    private static let multiBuyPattern =
        #/(?<quantity>\d{1,2})[ ]*(?:\bfor\b|\bpour\b|\/|@)[ ]*/#

    /// An optional per-separator, an optional quantity and a unit noun: `/100 g`, `par 100 g`,
    /// `le kg`, `lb`, `each`. The quantity carries decimals because random-weight labels print them.
    ///
    /// There is deliberately no word boundary before the noun: it would reject the attached forms
    /// labels print — `1.716kg`, `455g`, `/100g`. The boundary really wanted is "not preceded by a
    /// letter", which is a lookbehind, so `isFreestanding` checks it in Swift instead.
    ///
    /// `lb` accepts `ib` and `1b`: `l`, `i` and `1` are the same vertical stroke in most tag fonts.
    private static let phrasePattern =
        #/(?<separator>\/|\bpar\b|\bper\b|\ble\b|\bla\b|\bl['’])?[ ]*(?:(?<quantity>\d{1,4}(?:[.,]\d{1,3})?)[ ]*)?(?<noun>kg|kilo(?:gram)?s?|[li1]bs?|livres?|oz|onces?|ml|millilitres?|milliliters?|litres?|liters?|l(?!['’])|g(?:ram(?:me)?s?)?|each|ea|chaque|chacun|items?|unit[ée]?s?|pi[èe]ces?|pce|un)\b/#

    private static func phrase(atStartOf text: Substring, within gap: Int) -> UnitPhrase? {
        for match in text.matches(of: phrasePattern) {
            guard text.distance(from: text.startIndex, to: match.range.lowerBound) <= gap else {
                return nil
            }
            if let phrase = phrase(from: match) { return phrase }
        }
        return nil
    }

    private static func phrases(in text: String) -> [UnitPhrase] {
        text.matches(of: phrasePattern).compactMap(phrase(from:))
    }

    private typealias PhraseMatch = Regex<
        (Substring, separator: Substring?, quantity: Substring?, noun: Substring)
    >.Match

    private static func phrase(from match: PhraseMatch) -> UnitPhrase? {
        // The quantity needs the same guard as the noun: with `l` a live unit, the postal code
        // `K1L` otherwise reads as "1 litre" and becomes a pack size.
        guard isFreestanding(match.output.noun),
            match.output.quantity.map(isFreestanding) ?? true
        else { return nil }
        // A French label writes the same weight `1,528 kg`, and `Double` only parses a dot.
        let quantity = match.output.quantity
            .map { $0.replacingOccurrences(of: ",", with: ".") }
            .flatMap(Double.init)
        return UnitPhrase(
            range: match.range,
            amount: quantity ?? 1,
            hasExplicitQuantity: quantity != nil,
            hasSeparator: match.output.separator != nil,
            unit: unit(forNoun: String(match.output.noun))
        )
    }

    /// The lookbehind Swift Regex will not do: a unit noun or its quantity may follow a digit, a
    /// space or a slash, but never a letter. Without it "peach" ends in `each` and "big" in `g`.
    private static func isFreestanding(_ token: Substring) -> Bool {
        let line = token.base
        guard token.startIndex > line.startIndex else { return true }
        return !line[line.index(before: token.startIndex)].isLetter
    }

    private static func unit(forNoun noun: String) -> MeasureUnit {
        if noun.hasPrefix("kg") || noun.hasPrefix("kilo") { return .kilogram }
        if noun.hasPrefix("lb") || noun.hasPrefix("ib") || noun.hasPrefix("1b")
            || noun.hasPrefix("livre")
        {
            return .pound
        }
        if noun.hasPrefix("oz") || noun.hasPrefix("once") { return .ounce }
        if noun.hasPrefix("m") { return .millilitre }
        if noun.hasPrefix("lit") || noun == "l" { return .litre }
        if noun.hasPrefix("g") { return .gram }
        return .each
    }

    private static func money(in text: String) -> [MoneyMatch] {
        text.matches(of: moneyPattern).compactMap { match in
            let isCurrencyFormatted = match.output.lead != nil || match.output.trail != nil
            let whole = String(match.output.whole)
            let fraction = match.output.fraction.map(String.init)

            // A produce sign raises the cents — `$2⁴⁷` — and recognition returns the digits run
            // together with no decimal point. Three or four of them spans $1.00 to $99.99, which is
            // every price such a sign prints.
            let isImplicitCents =
                !isCurrencyFormatted && fraction == nil && (3...4).contains(whole.count)
            guard isCurrencyFormatted || fraction?.count == 2 || isImplicitCents else { return nil }

            guard var value = Double(whole) else { return nil }
            if let fraction, let digits = Double(fraction) {
                value += digits / pow(10, Double(fraction.count))
            }
            if match.output.lead == "¢" || match.output.trail == "¢" || isImplicitCents {
                value /= 100
            }
            guard value >= 0.01, value <= 999.99 else { return nil }
            return MoneyMatch(
                value: value,
                range: match.range,
                isCurrencyFormatted: isCurrencyFormatted,
                isImplicitCents: isImplicitCents
            )
        }
    }
}
