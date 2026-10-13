import Foundation
import SwiftData

/// Carries a store from before items had one good price per dimension. SwiftData's lightweight
/// migration adds the new columns empty; it cannot copy values, so this runs at launch.
///
/// A price the shopper set moves into the matching per-dimension column. A price the old bundled
/// seed set, and they never touched, is dropped, so an upgrade starts where a fresh install does:
/// with only the good prices the shopper chose; `StoreUpkeep.prune` then removes the seed items left
/// with nothing. Idempotent: a handled row's legacy column is zeroed.
@MainActor
enum LegacyGoodPriceMigration {
    static func run(in context: ModelContext) {
        let descriptor = FetchDescriptor<GroceryItem>(
            predicate: #Predicate { $0.goodPriceCanonical > 0 })
        guard let items = try? context.fetch(descriptor), !items.isEmpty else { return }
        for item in items {
            if item.userModified, !item.hasGoodPrice {
                let dimension = PriceDimension(rawValue: item.dimensionRaw) ?? .mass
                item.setGoodPrice(
                    NormalizedPrice(dimension: dimension, canonical: item.goodPriceCanonical))
            }
            item.goodPriceCanonical = 0
        }
        try? context.save()
    }
}
