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
            touch(trip, in: context)
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
        entry.savedName = item?.name ?? listEntry?.text ?? ""
        if entry.savedName.isEmpty {
            entry.unnamedOrdinal = trip.nextUnnamedOrdinal
        }
        if let crossing = listEntry ?? item.flatMap(trip.uncrossedEntry(linkedTo:)) {
            entry.listEntryID = crossing.id
            trip.setCrossed(true, for: crossing)
        }
        touch(trip, in: context)
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
        if let trip { trip.lastActivityAt = .now }
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
        entry.savedName = entry.item?.name ?? listEntry.text
        trip.setCrossed(true, for: listEntry)
        touch(trip, in: context)
    }

    static func setCrossed(_ crossed: Bool, for listEntry: ListEntry, in trip: Trip) {
        trip.setCrossed(crossed, for: listEntry)
        if let context = trip.modelContext { touch(trip, in: context) }
    }

    static func setQuantity(_ quantity: Double, for entry: CartEntry, in context: ModelContext) {
        guard quantity > 0 else { return }
        entry.quantity = quantity
        if let trip = entry.trip { touch(trip, in: context) } else { save(context) }
    }

    /// Finishing is when the cart's prices become history: by now the shopper has fixed typos,
    /// removed what they put back and matched what they had not named, so this is what they paid.
    static func finish(_ trip: Trip, at date: Date = .now, in context: ModelContext) {
        guard !trip.isFinished else { return }
        trip.isFinished = true
        trip.endedAt = date
        for entry in trip.orderedEntries {
            guard let item = entry.item, let unitPrice = entry.unitPrice else { continue }
            context.insert(
                PriceObservation(
                    price: unitPrice, reason: .bought, date: entry.addedAt,
                    verdict: entry.verdict, tripID: trip.id, item: item))
        }
        save(context)
    }

    /// A trip nobody has touched in this long was finished without saying so: it is closed out, so
    /// its prices are kept and the next shop starts with an empty cart. One that never got anything
    /// in its cart has nothing to keep and is discarded instead.
    static let idleLimit: TimeInterval = 6 * 60 * 60

    static func finishIdleTrip(now: Date = .now, in context: ModelContext) {
        guard let trip = activeTrip(in: context) else { return }
        let lastActivity =
            [trip.lastActivityAt, trip.startedAt, trip.orderedEntries.last?.addedAt]
            .compactMap { $0 }.max() ?? trip.startedAt
        guard now.timeIntervalSince(lastActivity) >= idleLimit else { return }
        if trip.orderedEntries.isEmpty {
            context.delete(trip)
            save(context)
        } else {
            finish(trip, at: lastActivity, in: context)
        }
    }

    private static func touch(_ trip: Trip, at date: Date = .now, in context: ModelContext) {
        trip.lastActivityAt = date
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
