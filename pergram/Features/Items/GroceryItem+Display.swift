import Foundation

extension GroceryItem {
    /// Every good price the item has, each in the shopper's preferred unit for its dimension:
    /// `$0.42/100g · $1.25/each`. `nil` when it has none yet.
    func goodPriceSummary(preferring preferred: MeasureUnit) -> String? {
        let prices = goodPrices.map { price in
            PriceDisplay.formatted(
                price, in: PriceDisplay.displayUnit(for: price.dimension, preferred: preferred))
        }
        return prices.isEmpty ? nil : prices.joined(separator: " · ")
    }
}
