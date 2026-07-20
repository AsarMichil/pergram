import Foundation

nonisolated enum Verdict: String, Sendable {
    case good
    case meh
    case bad
}

nonisolated enum VerdictEngine {
    /// Bands are inclusive on the low side: good `≤ baseline × 1.05`, meh up to `× 1.25`, bad above.
    static func verdict(pricePer100g: Double, baselinePer100g: Double) -> Verdict {
        let good = baselinePer100g * VerdictThresholds.goodMultiplier
        let meh = baselinePer100g * VerdictThresholds.mehMultiplier
        if pricePer100g <= good { return .good }
        if pricePer100g <= meh { return .meh }
        return .bad
    }

    /// A verdict needs a baseline; an unmatched item degrades to the bare normalized price and
    /// no verdict, which is also the entry point for "set this as my good price".
    static func evaluate(pricePer100g: Double, baselinePer100g: Double?) -> Verdict? {
        guard let baselinePer100g else { return nil }
        return verdict(pricePer100g: pricePer100g, baselinePer100g: baselinePer100g)
    }
}
