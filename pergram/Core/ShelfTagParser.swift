import Foundation

/// One recognized line of a shelf tag.
nonisolated struct ShelfTagLine: Equatable, Sendable {
    let text: String
    /// How tall this line is printed, as a fraction of the frame. The headline price is the biggest
    /// thing on a tag, so this is what breaks ties between competing prices — position cannot, since
    /// lines arrive in reading order.
    let prominence: Double

    init(_ text: String, prominence: Double = 0) {
        self.text = text
        self.prominence = prominence
    }
}

/// A shelf tag read into the Check screen's three fields.
///
/// `amount` and `unit` are `nil` when only a bare price was legible; they are filled when the
/// tag's printed unit price was parsed, so the value normalizes straight to `$/100g` or `$/each`.
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

/// Everything one frame yielded. Frames of the same tag disagree about which half they can read —
/// one resolves `149` and loses the `/LB`, the next resolves `/LB` and loses the price — so the
/// unpaired unit is reported rather than discarded, for a caller watching several frames to join up.
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

    /// `lines` must be in **reading order**, top to bottom: a tag prints its unit price as
    /// `$5.99` above `/lb` as often as beside it, and only reading order makes those two adjacent.
    /// Prominence, not position, decides which of two competing prices wins.
    static func candidate(from lines: [ShelfTagLine]) -> ScanCandidate? {
        reading(from: lines).candidate
    }

    /// As `candidate(from:)`, but also reporting a per-unit token the frame could not attach to any
    /// price. Only reported when the candidate has no unit of its own, since otherwise the tag has
    /// already said what it prices by.
    static func reading(from lines: [ShelfTagLine]) -> ShelfTagReading {
        let parsed = lines.map(ParsedLine.init(line:))
        // A produce sign prints `$2⁴⁷` and recognition returns `247` — no symbol, no decimal point,
        // indistinguishable from a PLU code on the text alone. So the strict reading runs first and
        // the reinterpretation only when the tag yielded nothing that was actually punctuated: it
        // can rescue a blank, never overrule a real price.
        let best =
            best(in: parsed, readingImplicitCents: false)
            ?? best(in: parsed, readingImplicitCents: true)
        let candidate = best.map { withPackSize($0, in: parsed) }
        return ShelfTagReading(
            candidate: candidate,
            unpairedUnit: candidate?.unit == nil ? unpairedUnit(in: parsed) : nil
        )
    }

    /// A per-unit token standing on its own. The separator is required: a bare noun or a
    /// quantity-and-noun pack size says nothing about how the tag prices, but `/lb` and `per kg` say
    /// it outright.
    private static func unpairedUnit(in lines: [ParsedLine]) -> ScanUnit? {
        lines.lazy.compactMap(\.separatorPhrase).first
    }

    private static func best(in parsed: [ParsedLine], readingImplicitCents: Bool) -> Ranked? {
        let headline = headlineThreshold(in: parsed)
        var best: Ranked? = poundKilogramPair(in: parsed, implicitCents: readingImplicitCents)
        var consumed: Set<MoneyKey> = []

        // Multi-buy first, because it is the one shape where the number that qualifies the price
        // sits *before* it: `2 for $5` is $2.50 each, and read as a plain price it is wrong by the
        // count. The money it consumes must not resurface as a price of its own.
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

        // A tag prints "$5.99" and "/lb" on separate lines as readily as on one. Pair a price that
        // ends a line with a unit phrase that opens the next.
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

    /// Only a currency symbol makes a number a price on its own. An unpunctuated digit run has to be
    /// *printed* like one instead: half again the size of a typical line on the tag. Relative on
    /// purpose, so it calibrates to how close the shot was framed rather than to a threshold guessed
    /// here, and `nil` when nothing stands out at all — which is what stops a frame holding two
    /// scraps of similar text from electing one of them the price.
    ///
    /// Deliberately a threshold rather than "must be the largest line". A tag setting the dollars
    /// larger than the cents — `1⁴⁹` — gets the `1` read as its own observation, and that stray
    /// glyph is taller than the `149` beside it. Demanding the maximum let a fragment of the price
    /// lock out the price.
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

    /// A produce sign nearly always prints both prices — `$2⁴⁷ /lb` above `$5⁴⁵ per kg`. Two
    /// unpunctuated numbers standing in the pound-to-kilogram ratio confirm each other: they are
    /// prices rather than product codes, and the smaller one is per pound. That holds even when the
    /// unit tokens themselves came back as `per ke`, which on these signs they usually do.
    private static func poundKilogramPair(in lines: [ParsedLine], implicitCents: Bool) -> Ranked? {
        guard let ratio = UnitGraph.standard.conversionFactor(from: .kilogram, to: .pound) else {
            return nil
        }
        let candidates = lines.flatMap { line in
            line.money.filter { $0.isImplicitCents == implicitCents }
                .map { (value: $0.value, line: line) }
        }
        var best: Ranked?
        for pound in candidates {
            for kilogram in candidates
            where abs(kilogram.value / pound.value - ratio) <= ratio * Self.ratioTolerance {
                best = better(
                    Ranked(
                        candidate: ScanCandidate(price: pound.value, amount: 1, unit: .pound),
                        isCrossValidated: true,
                        isUnitPrice: true,
                        isCurrencyFormatted: pound.line.money.contains {
                            $0.value == pound.value && $0.isCurrencyFormatted
                        },
                        prominence: pound.line.prominence,
                        value: pound.value
                    ), best)
            }
        }
        return best
    }

    /// Signs round the converted price to the cent, so the two never divide out exactly.
    private static let ratioTolerance = 0.015

    /// Plenty of tags print only a price and a net weight — `$5.45` over `455 g`, no unit price
    /// anywhere. That pair *is* a unit price, so it beats leaving the amount blank. It is applied
    /// last and only to a bare price, so a printed unit price always wins over inference.
    private static func withPackSize(_ best: Ranked, in lines: [ParsedLine]) -> ScanCandidate {
        guard !best.isUnitPrice, let pack = lines.lazy.compactMap(\.packSize).first else {
            return best.candidate
        }
        return ScanCandidate(price: best.candidate.price, amount: pack.amount, unit: pack.unit)
    }

    /// A price sitting next to a unit phrase reads as a unit price when either side says so: an
    /// explicit separator (`/100 g`, `par 100 g`), or a currency symbol against a bare noun
    /// (`$5.99 lb`). A quantity with no separator is a pack size instead — `$5.49 681 g` is an
    /// item price beside a net weight, so the price stays a plain price.
    /// An unpunctuated digit run needs the separator specifically: `545` beside `per kg` is a unit
    /// price, but `907` beside `g` is a net weight, and nothing in the digits tells them apart.
    private static func isUnitPrice(_ money: MoneyMatch, _ phrase: UnitPhrase) -> Bool {
        // `g` is a suffix of `kg` and `l` of `ml`, so dropping a character turns one real unit into
        // another — the only misreads that swap a valid reading for a different valid reading rather
        // than for nonsense. No tag prices by the single gram or millilitre; they print `/100 g`,
        // `/kg`, `/100 mL`, `/L`. So a base-unit reading with no quantity is a truncated one, and
        // `$6.57 /G` is not $657 per 100 g.
        if Self.baseUnits.contains(phrase.unit), !phrase.hasExplicitQuantity { return false }
        if money.isImplicitCents { return phrase.hasSeparator }
        return phrase.hasSeparator || (money.isCurrencyFormatted && !phrase.hasExplicitQuantity)
    }

    /// The units a tag counts in but never prices by on their own.
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
        /// Two prices on the tag agreeing with each other arithmetically. That beats a price sitting
        /// next to a unit token, because adjacency is a guess about layout and the ratio is not.
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
    /// A bare digit run read as dollars-and-cents: `247` for `$2⁴⁷`. Only ever trusted as a last
    /// resort, because on the text alone it is indistinguishable from a PLU code.
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

    /// `2 for $5`, `2/$5.00`, `3 pour 10,00 $` — a count, then a price for that many.
    ///
    /// The price has to be punctuated: `2/5` is a date, a score or a fraction, and `2 for 500` is
    /// nothing at all. Requiring the currency symbol or the cents is what keeps this from firing on
    /// ordinary text, since the word "for" is otherwise everywhere.
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

    /// A net weight or pack size: a quantity and a unit with no per-separator, standing clear of
    /// any price on the line. The overlap check is what stops the `45` of `$5.45 g` reading as a
    /// quantity.
    var packSize: (amount: Double, unit: MeasureUnit)? {
        for phrase in ParsedLine.phrases(in: text) {
            // Only a *currency-formatted* price blocks a pack size, because the currency symbol is
            // the one thing that distinguishes a price from a quantity. `$5.45 g` has to be stopped
            // from reading 5.45 as a weight; `1.89 L` is a bottle whose size is spelled exactly like
            // a price, and blocking on that cancelled the very size it sits inside.
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
    /// optional quantity cannot swallow the price's own decimals — `$0.50 each` would otherwise
    /// read as "50 each". Adjacent means at most a separating space or two.
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
    /// space that separates a price from the unit phrase after it. The `(?!\d)` guarding the cents
    /// is what stops a three-decimal net weight — `1.528 kg` — reading as the price `1.52`.
    private static let moneyPattern =
        #/(?:(?<lead>[$¢])[ ]?)?(?<whole>\d{1,4})(?:[.,](?<fraction>\d{1,2})(?!\d))?(?:[ ]?(?<trail>[$¢]))?/#

    private static let multiBuyPattern =
        #/(?<quantity>\d{1,2})[ ]*(?:\bfor\b|\bpour\b|\/|@)[ ]*/#

    /// An optional per-separator, an optional quantity and a unit noun: `/100 g`, `par 100 g`,
    /// `le kg`, `lb`, `each`. The quantity carries decimals because random-weight labels print
    /// them — `1.528 kg`.
    ///
    /// There is deliberately no word boundary before the noun: it would also reject the attached
    /// forms labels actually print — `1.716kg`, `455g`, `/100g`. The boundary that is really wanted
    /// is "not preceded by a letter", which is a lookbehind, so `isNounFreestanding` checks it in
    /// Swift instead.
    ///
    /// `lb` accepts `ib` and `1b` because the small `/lb` beside a big price is where recognition
    /// is weakest, and `l`, `i` and `1` are the same vertical stroke in most tag fonts.
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
        // The quantity needs the same guard as the noun, and volume is what made it matter: with
        // `l` a live unit, the postal code `K1L` reads as "1 litre" and becomes a pack size.
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
    /// space or a slash, but never a letter. Without it "peach" ends in `each`, "big" ends in `g`,
    /// and the postal code `K1L` is a litre of something.
    private static func isFreestanding(_ token: Substring) -> Bool {
        let line = token.base
        guard token.startIndex > line.startIndex else { return true }
        return !line[line.index(before: token.startIndex)].isLetter
    }

    private static func unit(forNoun noun: String) -> MeasureUnit {
        if noun.hasPrefix("kg") || noun.hasPrefix("kilo") { return .kilogram }
        // `ib` and `1b` are the same two strokes as `lb`; the pattern accepts them, so the mapping
        // has to as well.
        if noun.hasPrefix("lb") || noun.hasPrefix("ib") || noun.hasPrefix("1b")
            || noun.hasPrefix("livre")
        {
            return .pound
        }
        if noun.hasPrefix("oz") || noun.hasPrefix("once") { return .ounce }
        if noun.hasPrefix("m") { return .millilitre }
        if noun.hasPrefix("lit") || noun.hasPrefix("liter") || noun == "l" { return .litre }
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
            // every price such a sign prints. It is kept as a *possible* reading, not a price:
            // `isImplicitCents` is what stops a PLU code becoming $40.11.
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
