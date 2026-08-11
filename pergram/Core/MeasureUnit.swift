import Foundation

nonisolated enum PriceDimension: String, CaseIterable, Codable, Sendable {
    case mass
    case count
}

nonisolated enum MeasureUnit: String, CaseIterable, Codable, Sendable {
    case gram
    case kilogram
    case pound
    case ounce
    case per100Grams
    case each

    /// Mass units interconvert through the gram-anchored `UnitGraph`; `.each` is its own dimension
    /// with no conversion into mass, so prices in different dimensions must never be compared.
    var dimension: PriceDimension {
        switch self {
        case .each: return .count
        default: return .mass
        }
    }

    /// The canonical unit a price in this dimension is normalized to: `$/100g` for mass, `$/each`
    /// for count.
    static func canonicalUnit(for dimension: PriceDimension) -> MeasureUnit {
        switch dimension {
        case .mass: return .per100Grams
        case .count: return .each
        }
    }
}
