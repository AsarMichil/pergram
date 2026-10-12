import Foundation
import SwiftData

nonisolated enum CheckSource: String, Codable, Sendable {
    case keypad
    case scan
}

/// Why a price was kept. Only prices the shopper acted on are recorded, because a price merely seen
/// on a tag says nothing about what they pay or what they consider good.
nonisolated enum ObservationReason: String, Codable, Sendable {
    /// Bookmarked before acting on a price was the bar. Kept readable; no longer written.
    case seenOnKeypad = "keypad"
    case seenOnScan = "scan"
    /// In the cart when a trip was finished.
    case bought
    /// Saved or updated as the item's good price.
    case goodPrice = "good-price"
}

/// The price history a trend feature will read. v1 records these and builds no UI on them.
@Model
final class PriceObservation {
    /// The observed price in its dimension's canonical unit (`$/100g`, `$/100mL` or `$/each`).
    /// Renamed from `pricePer100g`; SwiftData migrates the column in place via `originalName`.
    @Attribute(originalName: "pricePer100g")
    var priceCanonical: Double = 0
    var date: Date = Date.distantPast
    /// An `ObservationReason` raw value. Named for its first meaning, how the price was entered.
    var sourceRawValue: String = ObservationReason.seenOnKeypad.rawValue
    /// Which of the item's good prices this is comparable with, now that an item can have one per
    /// dimension. Defaults to mass, which every observation recorded before this was.
    var dimensionRaw: String = PriceDimension.mass.rawValue
    /// The verdict at the time, so "good buys" can be counted without re-judging old prices against
    /// a good price that has since moved.
    var verdictRaw: String?
    var tripID: UUID?
    var item: GroceryItem?

    var reason: ObservationReason {
        get { ObservationReason(rawValue: sourceRawValue) ?? .seenOnKeypad }
        set { sourceRawValue = newValue.rawValue }
    }

    var verdict: Verdict? { verdictRaw.flatMap(Verdict.init(rawValue:)) }

    init(
        price: NormalizedPrice, reason: ObservationReason, date: Date = .now,
        verdict: Verdict? = nil, tripID: UUID? = nil, item: GroceryItem? = nil
    ) {
        self.priceCanonical = price.canonical
        self.dimensionRaw = price.dimension.rawValue
        self.date = date
        self.sourceRawValue = reason.rawValue
        self.verdictRaw = verdict?.rawValue
        self.tripID = tripID
        self.item = item
    }
}

/// One price the shopper looked at in Check, kept so counts can be drawn later — prices checked,
/// good ones found — without deciding today which counts matter.
@Model
final class PriceCheck {
    var date: Date = Date.distantPast
    var priceCanonical: Double = 0
    var dimensionRaw: String = PriceDimension.mass.rawValue
    var verdictRaw: String?
    var sourceRawValue: String = CheckSource.keypad.rawValue
    /// A name rather than a relationship: a check outlives the item it was against.
    var itemName: String?

    init(
        price: NormalizedPrice, verdict: Verdict?, source: CheckSource, itemName: String?,
        date: Date = .now
    ) {
        self.date = date
        self.priceCanonical = price.canonical
        self.dimensionRaw = price.dimension.rawValue
        self.verdictRaw = verdict?.rawValue
        self.sourceRawValue = source.rawValue
        self.itemName = itemName
    }

    var verdict: Verdict? { verdictRaw.flatMap(Verdict.init(rawValue:)) }
}
