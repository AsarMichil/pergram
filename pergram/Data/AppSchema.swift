import SwiftData

enum AppSchema {
    static let schema = Schema([
        GroceryItem.self, PriceObservation.self, GroceryList.self, ListEntry.self, Trip.self,
        CartEntry.self, PriceCheck.self,
    ])
}
