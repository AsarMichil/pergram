import Foundation
import SwiftData

nonisolated enum CheckSource: String, Codable, Sendable {
    case keypad
    case scan
}

/// Written by every check so a trend feature has history from a user's first day, not the
/// feature's. v1 records these and builds no UI on them.
@Model
final class PriceObservation {
    var pricePer100g: Double = 0
    var date: Date = Date.distantPast
    var sourceRawValue: String = CheckSource.keypad.rawValue
    var item: GroceryItem?

    var source: CheckSource {
        get { CheckSource(rawValue: sourceRawValue) ?? .keypad }
        set { sourceRawValue = newValue.rawValue }
    }

    init(
        pricePer100g: Double = 0, date: Date = .now, source: CheckSource = .keypad,
        item: GroceryItem? = nil
    ) {
        self.pricePer100g = pricePer100g
        self.date = date
        self.sourceRawValue = source.rawValue
        self.item = item
    }
}
