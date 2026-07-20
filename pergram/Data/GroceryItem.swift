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
    var goodPricePer100g: Double = 0
    var userModified: Bool = false
    var updatedAt: Date = Date.distantPast

    @Relationship(deleteRule: .cascade, inverse: \PriceObservation.item)
    var observations: [PriceObservation]? = []

    init(
        id: String = "",
        name: String = "",
        aliases: [String] = [],
        category: String = "",
        goodPricePer100g: Double = 0,
        userModified: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.goodPricePer100g = goodPricePer100g
        self.userModified = userModified
        self.updatedAt = updatedAt
    }
}
