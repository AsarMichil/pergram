import Foundation

nonisolated enum PriceDimension: String, CaseIterable, Codable, Sendable {
    case mass
    case volume
    case count
}

nonisolated enum MeasureUnit: String, CaseIterable, Codable, Sendable {
    case gram
    case kilogram
    case pound
    case ounce
    case per100Grams
    case millilitre
    case litre
    case per100Millilitres
    case each

    /// Mass and volume are each a connected component of the `UnitGraph` — grams interconvert with
    /// pounds, millilitres with litres, and neither crosses into the other. `.each` converts to
    /// nothing at all. Exhaustive on purpose: a new unit defaulting silently into mass would be
    /// wrong in a way nothing catches.
    var dimension: PriceDimension {
        switch self {
        case .gram, .kilogram, .pound, .ounce, .per100Grams: return .mass
        case .millilitre, .litre, .per100Millilitres: return .volume
        case .each: return .count
        }
    }

    /// The canonical unit a price in this dimension is normalized to: `$/100g` for mass,
    /// `$/100mL` for volume, `$/each` for count.
    static func canonicalUnit(for dimension: PriceDimension) -> MeasureUnit {
        switch dimension {
        case .mass: return .per100Grams
        case .volume: return .per100Millilitres
        case .count: return .each
        }
    }
}
