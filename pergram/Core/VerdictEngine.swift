import Foundation

nonisolated enum Verdict: String, Sendable {
    case good
    case meh
    case bad
}

nonisolated enum VerdictEngine {
    /// Bands are inclusive on the low side: good `≤ baseline × 1.05`, meh up to `× 1.25`, bad above.
    /// `price` and `baseline` must already be in the same canonical unit (see `NormalizedPrice`);
    /// comparing across dimensions is the caller's error to prevent, not this function's.
    static func verdict(price: Double, baseline: Double) -> Verdict {
        let good = baseline * VerdictThresholds.goodMultiplier
        let meh = baseline * VerdictThresholds.mehMultiplier
        if price <= good { return .good }
        if price <= meh { return .meh }
        return .bad
    }
}
