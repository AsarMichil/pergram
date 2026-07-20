import Foundation

/// A price paired with the mass it buys, normalized to grams so every downstream comparison
/// speaks one language. Storing money and mass separately keeps the inverse (grams per dollar)
/// a reciprocal rather than a second code path.
nonisolated struct Rate: Equatable, Sendable {
    let money: Double
    let grams: Double

    init(money: Double, grams: Double) {
        self.money = money
        self.grams = grams
    }

    init?(money: Double, quantity: Double, unit: MeasureUnit, graph: UnitGraph = .standard) {
        guard let grams = graph.convert(quantity, from: unit, to: .gram) else { return nil }
        self.init(money: money, grams: grams)
    }

    var pricePer100g: Double {
        guard grams > 0 else { return 0 }
        return money / (grams / 100)
    }

    /// The reciprocal view — how many grams a dollar buys. Clamped at a `$0` input so the engine,
    /// not the UI, owns the divide-by-zero edge. No v1 screen surfaces this yet.
    func gramsPerDollar() -> Double {
        guard money > 0 else { return 0 }
        return grams / money
    }
}
