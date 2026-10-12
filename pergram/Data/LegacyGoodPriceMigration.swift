import Foundation
import SwiftData

/// Carries a store from before items had one good price per dimension. SwiftData's lightweight
/// migration adds the new columns empty; it cannot copy values, so this runs at launch.
///
/// A price the shopper set moves into the matching per-dimension column. A price the old bundled
/// seed set, and they never touched, is dropped, so an upgrade starts where a fresh install does:
/// with only the good prices the shopper chose. Idempotent: a handled row's legacy column is zeroed.
@MainActor
enum LegacyGoodPriceMigration {
    static func run(in context: ModelContext) {
        let descriptor = FetchDescriptor<GroceryItem>(
            predicate: #Predicate { $0.goodPriceCanonical > 0 })
        guard let items = try? context.fetch(descriptor), !items.isEmpty else { return }
        for item in items {
            if !item.userModified {
                if isUnreferenced(item) {
                    context.delete(item)
                } else {
                    item.goodPriceCanonical = 0
                }
                continue
            }
            if !item.hasGoodPrice {
                let dimension = PriceDimension(rawValue: item.dimensionRaw) ?? .mass
                item.setGoodPrice(
                    NormalizedPrice(dimension: dimension, canonical: item.goodPriceCanonical))
            }
            item.goodPriceCanonical = 0
        }
        try? context.save()
    }

    /// Nothing on a list, in a cart or in price history points at it, so removing it loses nothing.
    private static func isUnreferenced(_ item: GroceryItem) -> Bool {
        (item.listEntries ?? []).isEmpty && (item.cartEntries ?? []).isEmpty
            && (item.observations ?? []).isEmpty
    }
}
