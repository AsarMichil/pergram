import Foundation
import SwiftData

/// Moves the single good price stores held before items could have one per dimension into the
/// matching per-dimension column. SwiftData's lightweight migration adds the new columns empty; it
/// cannot copy values, so this runs at launch. Idempotent: a moved price leaves the legacy column at
/// zero, and an item that already has per-dimension prices is never overwritten.
@MainActor
enum LegacyGoodPriceMigration {
    static func run(in context: ModelContext) {
        let descriptor = FetchDescriptor<GroceryItem>(
            predicate: #Predicate { $0.goodPriceCanonical > 0 })
        guard let items = try? context.fetch(descriptor), !items.isEmpty else { return }
        for item in items {
            if !item.hasGoodPrice {
                let dimension = PriceDimension(rawValue: item.dimensionRaw) ?? .mass
                item.setGoodPrice(
                    NormalizedPrice(dimension: dimension, canonical: item.goodPriceCanonical))
            }
            item.goodPriceCanonical = 0
        }
        try? context.save()
    }
}
