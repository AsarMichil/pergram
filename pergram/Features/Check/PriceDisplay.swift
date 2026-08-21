import Foundation

/// Formats a `NormalizedPrice` into the user's chosen display unit, riding the same `UnitGraph` the
/// Core engine uses so that cycling the unit is a formatting concern, not a second conversion path.
nonisolated enum PriceDisplay {
    static func units(for dimension: PriceDimension) -> [MeasureUnit] {
        switch dimension {
        case .mass: return [.per100Grams, .kilogram, .pound, .ounce]
        case .volume: return [.per100Millilitres, .litre]
        case .count: return [.each]
        }
    }

    static func displayUnit(for dimension: PriceDimension, preferred: MeasureUnit) -> MeasureUnit {
        let allowed = units(for: dimension)
        return allowed.contains(preferred) ? preferred : allowed[0]
    }

    static func value(_ price: NormalizedPrice, in unit: MeasureUnit) -> Double {
        switch price.dimension {
        case .mass: return scaled(price.canonical, to: unit, base: .gram)
        case .volume: return scaled(price.canonical, to: unit, base: .millilitre)
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
        case .millilitre: return "/mL"
        case .litre: return "/L"
        case .per100Millilitres: return "/100mL"
        case .each: return "/each"
        }
    }

    static func next(after unit: MeasureUnit, in dimension: PriceDimension) -> MeasureUnit {
        let order = units(for: dimension)
        guard let index = order.firstIndex(of: unit) else { return order[0] }
        return order[(index + 1) % order.count]
    }

    /// The canonical value is per 100 of the dimension's base, so scaling to any other unit in the
    /// dimension is one graph hop.
    private static func scaled(
        _ canonical: Double, to unit: MeasureUnit, base: MeasureUnit,
        graph: UnitGraph = .standard
    ) -> Double {
        let basePerUnit = graph.convert(1, from: unit, to: base) ?? 100
        return canonical / 100 * basePerUnit
    }
}
