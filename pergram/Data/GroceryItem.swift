import Foundation
import SwiftData

/// Every property is defaulted and no attribute is `.unique`, so the model can be mirrored to
/// CloudKit later by flipping a checkbox rather than performing a migration.
@Model
final class GroceryItem {
    var id: String = ""
    var name: String = ""
    var aliases: [String] = []
    var category: String = ""

    /// The good price in its dimension's canonical unit: `$/100g` for mass, `$/each` for count.
    /// Renamed from `goodPricePer100g`; SwiftData migrates the column in place via `originalName`.
    @Attribute(originalName: "goodPricePer100g")
    var goodPriceCanonical: Double = 0
    var dimensionRaw: String = PriceDimension.mass.rawValue

    var userModified: Bool = false
    var updatedAt: Date = Date.distantPast

    @Relationship(deleteRule: .cascade, inverse: \PriceObservation.item)
    var observations: [PriceObservation]? = []

    var dimension: PriceDimension {
        get { PriceDimension(rawValue: dimensionRaw) ?? .mass }
        set { dimensionRaw = newValue.rawValue }
    }

    init(
        id: String = "",
        name: String = "",
        aliases: [String] = [],
        category: String = "",
        goodPriceCanonical: Double = 0,
        dimension: PriceDimension = .mass,
        userModified: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.goodPriceCanonical = goodPriceCanonical
        self.dimensionRaw = dimension.rawValue
        self.userModified = userModified
        self.updatedAt = updatedAt
    }
}
