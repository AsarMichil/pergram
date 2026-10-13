import Foundation
import SwiftData

/// One shop. Cross-offs live here rather than on the list, which is what lets a list be reused: the
/// next trip starts with nothing crossed.
@Model
final class Trip {
    var id: UUID = UUID()
    var startedAt: Date = Date.distantPast
    var endedAt: Date?
    var isFinished: Bool = false
    var list: GroceryList?
    var crossedEntryIDs: [UUID] = []
    /// Any change to the trip, prep and cross-offs included, so a list planned in the morning is not
    /// taken for an abandoned trip by the afternoon.
    var lastActivityAt: Date = Date.distantPast
    /// Copied when the trip finishes, so a past trip still reads "Weekly" after the list is renamed
    /// or deleted, and still knows what was missed after the list is edited.
    var listName: String = ""
    var missedItemNames: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \CartEntry.trip)
    var entries: [CartEntry]? = []

    init(startedAt: Date = .now, list: GroceryList? = nil) {
        self.startedAt = startedAt
        self.lastActivityAt = startedAt
        self.list = list
    }

    var orderedEntries: [CartEntry] {
        (entries ?? []).sorted { $0.addedAt < $1.addedAt }
    }

    var tally: CartTally { CartTally(orderedEntries.map(\.line)) }

    /// Crossed when its item is in the cart, or when the shopper crossed it by hand. Following the
    /// cart is what makes adding a price cross the list off without any bookkeeping between them.
    func isCrossed(_ entry: ListEntry) -> Bool {
        isInCart(entry) || crossedEntryIDs.contains(entry.id)
    }

    func isInCart(_ entry: ListEntry) -> Bool {
        guard let item = entry.item else { return false }
        return (entries ?? []).contains { $0.item === item }
    }

    /// Only crossings made by hand are stored; an entry in the cart stays crossed until it leaves.
    func setCrossed(_ crossed: Bool, for entry: ListEntry) {
        if crossed {
            guard !crossedEntryIDs.contains(entry.id) else { return }
            crossedEntryIDs.append(entry.id)
        } else {
            crossedEntryIDs.removeAll { $0 == entry.id }
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
    /// The name it was added or matched under, so the label survives the item or list entry going
    /// away — a switched list, a deleted item, an update that dropped the entry.
    var savedName: String = ""
    var unitPriceCanonical: Double?
    var dimensionRaw: String?
    /// The verdict when it was added. It does not follow later edits to the good price.
    var verdictRaw: String?
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

    var label: String {
        if let item { return item.name }
        return savedName.isEmpty ? "Item \(unnamedOrdinal)" : savedName
    }
}
