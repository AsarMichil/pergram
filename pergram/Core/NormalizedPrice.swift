import Foundation

/// A price reduced to its dimension's canonical unit: `$/100g` for mass, `$/100mL` for volume,
/// `$/each` for count.
/// This is the single normalization path — every screen and the verdict engine speak `canonical`,
/// and comparisons are only meaningful between two values of the same `dimension`.
nonisolated struct NormalizedPrice: Equatable, Sendable {
    let dimension: PriceDimension
    let canonical: Double

    init(dimension: PriceDimension, canonical: Double) {
        self.dimension = dimension
        self.canonical = canonical
    }

    /// `nil` for non-positive money/quantity, or a quantity that cannot reach its dimension's base.
    init?(money: Double, quantity: Double, unit: MeasureUnit, graph: UnitGraph = .standard) {
        guard money > 0, quantity > 0 else { return nil }
        switch unit.dimension {
        case .mass:
            guard let rate = Rate(money: money, quantity: quantity, unit: unit, graph: graph) else {
                return nil
            }
            self.init(dimension: .mass, canonical: rate.pricePer100g)
        case .volume:
            guard let millilitres = graph.convert(quantity, from: unit, to: .millilitre) else {
                return nil
            }
            self.init(dimension: .volume, canonical: money / (millilitres / 100))
        case .count:
            self.init(dimension: .count, canonical: money / quantity)
        }
    }
}
