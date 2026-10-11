import Foundation
import SwiftData

/// Every change to a trip goes through here, so the rules tying the cart to the list's cross-offs
/// live in one place rather than in whichever view the shopper happened to tap.
@MainActor
enum Shopping {
    static func activeTrip(in context: ModelContext) -> Trip? {
        var descriptor = FetchDescriptor<Trip>(
            predicate: #Predicate { !$0.isFinished },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Returns the running trip rather than starting a second one; a list passed in becomes the one
    /// it is shopping.
    @discardableResult
    static func startTrip(shopping list: GroceryList? = nil, in context: ModelContext) -> Trip {
        if let trip = activeTrip(in: context) {
            if let list { trip.list = list }
            save(context)
            return trip
        }
        let trip = Trip(list: list)
        context.insert(trip)
        save(context)
        return trip
    }

    @discardableResult
    static func addToCart(
        price: Double,
        unitPrice: NormalizedPrice?,
        item: GroceryItem?,
        listEntry: ListEntry? = nil,
        in context: ModelContext
    ) -> CartEntry {
        let trip = startTrip(in: context)
        let item = item ?? listEntry?.item
        let entry = CartEntry(
            price: price,
            unitPrice: unitPrice,
            verdict: unitPrice.flatMap { item?.verdict(for: $0) }
        )
        context.insert(entry)
        entry.trip = trip
        entry.item = item
        if entry.item == nil && listEntry == nil {
            entry.unnamedOrdinal = trip.nextUnnamedOrdinal
        }
        if let crossing = listEntry ?? item.flatMap(trip.uncrossedEntry(linkedTo:)) {
            entry.listEntryID = crossing.id
            trip.setCrossed(true, for: crossing)
        }
        save(context)
        return entry
    }

    static func remove(_ entry: CartEntry, in context: ModelContext) {
        let trip = entry.trip
        let listEntryID = entry.listEntryID
        entry.trip = nil
        context.delete(entry)
        if let trip, let listEntryID {
            uncrossIfUnclaimed(listEntryID, in: trip)
        }
        save(context)
    }

    /// "This was the eggs": the entry takes the list entry's item, and the verdict that item gives.
    static func match(_ entry: CartEntry, to listEntry: ListEntry, in context: ModelContext) {
        guard let trip = entry.trip else { return }
        let previous = entry.listEntryID
        entry.listEntryID = listEntry.id
        if let previous, previous != listEntry.id {
            uncrossIfUnclaimed(previous, in: trip)
        }
        if entry.item == nil, let item = listEntry.item {
            entry.item = item
            entry.verdict = entry.unitPrice.flatMap(item.verdict(for:))
        }
        trip.setCrossed(true, for: listEntry)
        save(context)
    }

    static func setCrossed(_ crossed: Bool, for listEntry: ListEntry, in trip: Trip) {
        trip.setCrossed(crossed, for: listEntry)
        trip.modelContext.map(save)
    }

    static func setQuantity(_ quantity: Double, for entry: CartEntry, in context: ModelContext) {
        guard quantity > 0 else { return }
        entry.quantity = quantity
        save(context)
    }

    static func finish(_ trip: Trip, in context: ModelContext) {
        trip.isFinished = true
        trip.endedAt = .now
        save(context)
    }

    private static func uncrossIfUnclaimed(_ listEntryID: UUID, in trip: Trip) {
        let stillClaimed = (trip.entries ?? []).contains { $0.listEntryID == listEntryID }
        guard !stillClaimed else { return }
        trip.crossedEntryIDs.removeAll { $0 == listEntryID }
    }

    private static func save(_ context: ModelContext) {
        try? context.save()
    }
}
