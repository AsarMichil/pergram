import Foundation

/// Converts a canonical CAD-per-100g price into the user's chosen display unit by riding the
/// same `UnitGraph` the Core engine uses, so the cycle is a formatting concern, not a second
/// conversion path.
nonisolated enum PriceDisplay {
    static let cycleOrder: [MeasureUnit] = [.per100Grams, .kilogram, .pound, .ounce]

    static func price(
        per100g pricePer100g: Double, in unit: MeasureUnit, graph: UnitGraph = .standard
    )
        -> Double
    {
        let gramsPerUnit = graph.convert(1, from: unit, to: .gram) ?? 100
        return pricePer100g / 100 * gramsPerUnit
    }

    static func suffix(for unit: MeasureUnit) -> String {
        switch unit {
        case .gram: return "/g"
        case .kilogram: return "/kg"
        case .pound: return "/lb"
        case .ounce: return "/oz"
        case .per100Grams: return "/100g"
        case .each: return "/each"
        }
    }

    static func amountUnitLabel(for unit: MeasureUnit) -> String {
        switch unit {
        case .gram: return "g"
        case .kilogram: return "kg"
        case .pound: return "lb"
        case .ounce: return "oz"
        case .per100Grams: return "/100g"
        case .each: return "each"
        }
    }

    static func next(after unit: MeasureUnit) -> MeasureUnit {
        guard let index = cycleOrder.firstIndex(of: unit) else { return cycleOrder[0] }
        return cycleOrder[(index + 1) % cycleOrder.count]
    }
}
