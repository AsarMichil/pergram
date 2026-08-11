import Foundation

/// Formats a `NormalizedPrice` into the user's chosen display unit. For mass this rides the same
/// `UnitGraph` the Core engine uses, so cycling is a formatting concern, not a second conversion
/// path; for count there is a single unit (`/each`) and nothing to convert.
nonisolated enum PriceDisplay {
    static func units(for dimension: PriceDimension) -> [MeasureUnit] {
        switch dimension {
        case .mass: return [.per100Grams, .kilogram, .pound, .ounce]
        case .count: return [.each]
        }
    }

    /// The unit to display a value of `dimension` in, honoring the user's stored preference when it
    /// belongs to that dimension and falling back to the dimension's canonical unit otherwise.
    static func displayUnit(for dimension: PriceDimension, preferred: MeasureUnit) -> MeasureUnit {
        let allowed = units(for: dimension)
        return allowed.contains(preferred) ? preferred : allowed[0]
    }

    static func value(_ price: NormalizedPrice, in unit: MeasureUnit) -> Double {
        switch price.dimension {
        case .mass: return massValue(per100g: price.canonical, in: unit)
        case .count: return price.canonical
        }
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

    static func next(after unit: MeasureUnit, in dimension: PriceDimension) -> MeasureUnit {
        let order = units(for: dimension)
        guard let index = order.firstIndex(of: unit) else { return order[0] }
        return order[(index + 1) % order.count]
    }

    private static func massValue(
        per100g pricePer100g: Double, in unit: MeasureUnit, graph: UnitGraph = .standard
    ) -> Double {
        let gramsPerUnit = graph.convert(1, from: unit, to: .gram) ?? 100
        return pricePer100g / 100 * gramsPerUnit
    }
}
