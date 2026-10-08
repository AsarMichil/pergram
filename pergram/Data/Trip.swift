import Foundation
import SwiftData

/// One shop. Crossed-off list entries live here rather than on the list, which is what lets a list
/// be reused: the next trip starts with nothing crossed.
@Model
final class Trip {
    var id: UUID = UUID()
    var startedAt: Date = Date.distantPast
    var endedAt: Date?
    var isFinished: Bool = false
    var list: GroceryList?
    var crossedEntryIDs: [UUID] = []

    @Relationship(deleteRule: .cascade, inverse: \CartEntry.trip)
    var entries: [CartEntry]? = []

    init(startedAt: Date = .now, list: GroceryList? = nil) {
        self.startedAt = startedAt
        self.list = list
    }

    var orderedEntries: [CartEntry] {
        (entries ?? []).sorted { $0.addedAt < $1.addedAt }
    }

    var tally: CartTally { CartTally(orderedEntries.map(\.line)) }

    func isCrossed(_ entry: ListEntry) -> Bool {
        crossedEntryIDs.contains(entry.id)
    }

    func setCrossed(_ crossed: Bool, for entry: ListEntry) {
        if crossed {
            guard !isCrossed(entry) else { return }
            crossedEntryIDs.append(entry.id)
        } else {
            crossedEntryIDs.removeAll { $0 == entry.id }
        }
    }

    /// The entry an add-to-cart should cross when the shopper named an item but not a list entry.
    func uncrossedEntry(linkedTo item: GroceryItem) -> ListEntry? {
        list?.orderedEntries.first { entry in
            entry.item?.persistentModelID == item.persistentModelID && !isCrossed(entry)
        }
    }

    var nextUnnamedOrdinal: Int {
        (entries ?? []).map(\.unnamedOrdinal).max().map { $0 + 1 } ?? 1
    }
}

@Model
final class CartEntry {
    var id: UUID = UUID()
    var addedAt: Date = Date.distantPast
    /// The tag's money for the amount entered — what one of these costs, not a unit price.
    var price: Double = 0
    /// Fractional so a per-weight tag can be multiplied out: `$5/100g × 3.5`.
    var quantity: Double = 1
    /// Labels an entry with no item as "Item N". Never renumbered on delete, because the label is
    /// what the shopper remembers from the shelf.
    var unnamedOrdinal: Int = 0
    var unitPriceCanonical: Double?
    var dimensionRaw: String?
    /// The verdict when it was added. It does not follow later edits to the good price.
    var verdictRaw: String?
    var listEntryID: UUID?
    var item: GroceryItem?
    var trip: Trip?

    init(
        price: Double = 0,
        quantity: Double = 1,
        unitPrice: NormalizedPrice? = nil,
        verdict: Verdict? = nil,
        addedAt: Date = .now
    ) {
        self.price = price
        self.quantity = quantity
        self.unitPriceCanonical = unitPrice?.canonical
        self.dimensionRaw = unitPrice?.dimension.rawValue
        self.verdictRaw = verdict?.rawValue
        self.addedAt = addedAt
    }

    var verdict: Verdict? {
        get { verdictRaw.flatMap(Verdict.init(rawValue:)) }
        set { verdictRaw = newValue?.rawValue }
    }

    var unitPrice: NormalizedPrice? {
        guard let unitPriceCanonical, let dimension = dimensionRaw.flatMap(PriceDimension.init)
        else { return nil }
        return NormalizedPrice(dimension: dimension, canonical: unitPriceCanonical)
    }

    var line: CartLine { CartLine(price: price, quantity: quantity, verdict: verdict) }

    func label(listEntry: ListEntry?) -> String {
        if let item { return item.name }
        if let listEntry { return listEntry.text }
        return "Item \(unnamedOrdinal)"
    }
}
