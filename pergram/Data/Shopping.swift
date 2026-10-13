import Foundation
import SwiftData

/// Every change to a trip goes through here, so its rules live in one place rather than in whichever
/// view the shopper happened to tap.
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
        price: Double, unitPrice: NormalizedPrice?, item: GroceryItem?, in context: ModelContext
    ) -> CartEntry {
        let trip = startTrip(in: context)
        let entry = CartEntry(
            price: price,
            unitPrice: unitPrice,
            verdict: unitPrice.flatMap { item?.verdict(for: $0) }
        )
        context.insert(entry)
        entry.trip = trip
        entry.item = item
        entry.savedName = item?.name ?? ""
        if item == nil {
            entry.unnamedOrdinal = trip.nextUnnamedOrdinal
        }
        touch(trip, in: context)
        return entry
    }

    static func remove(_ entry: CartEntry, in context: ModelContext) {
        let trip = entry.trip
        entry.trip = nil
        context.delete(entry)
        if let trip { trip.lastActivityAt = .now }
        save(context)
    }

    /// "That was the eggs": a price-only entry takes the item, and the verdict that item gives.
    static func name(_ entry: CartEntry, as item: GroceryItem, in context: ModelContext) {
        entry.item = item
        entry.savedName = item.name
        entry.verdict = entry.unitPrice.flatMap(item.verdict(for:))
        if let trip = entry.trip { touch(trip, in: context) } else { save(context) }
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
    /// removed what they put back and named what they had not, so this is what they paid.
    static func finish(_ trip: Trip, at date: Date = .now, in context: ModelContext) {
        guard !trip.isFinished else { return }
        trip.isFinished = true
        trip.endedAt = date
        trip.listName = trip.list?.name ?? ""
        trip.missedItemNames = (trip.list?.orderedEntries ?? [])
            .filter { !$0.isSkipped && !trip.isCrossed($0) }
            .map(\.name)
        for entry in trip.orderedEntries {
            guard let item = entry.item, let unitPrice = entry.unitPrice else { continue }
            context.insert(
                PriceObservation(
                    price: unitPrice, reason: .bought, date: entry.addedAt,
                    verdict: entry.verdict, tripID: trip.id, item: item))
        }
        save(context)
    }

    struct GoodPriceSuggestion: Identifiable {
        let item: GroceryItem
        let price: NormalizedPrice

        var id: String { "\(item.persistentModelID)-\(price.dimension.rawValue)" }
    }

    /// Items bought on this trip with no good price in the way they were bought, each offered the
    /// lowest price paid — a first shop is how a fresh install gets its good prices.
    static func goodPriceSuggestions(for trip: Trip) -> [GoodPriceSuggestion] {
        var lowest: [String: GoodPriceSuggestion] = [:]
        for entry in trip.orderedEntries {
            guard let item = entry.item, let price = entry.unitPrice,
                item.goodPrice(for: price.dimension) == nil
            else { continue }
            let suggestion = GoodPriceSuggestion(item: item, price: price)
            if price.canonical < lowest[suggestion.id]?.price.canonical ?? .infinity {
                lowest[suggestion.id] = suggestion
            }
        }
        return lowest.values.sorted { $0.item.name < $1.item.name }
    }

    static func useAsGoodPrice(_ suggestion: GoodPriceSuggestion, in context: ModelContext) {
        suggestion.item.setGoodPrice(suggestion.price)
        suggestion.item.userModified = true
        suggestion.item.updatedAt = .now
        context.insert(
            PriceObservation(price: suggestion.price, reason: .goodPrice, item: suggestion.item))
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

    private static func save(_ context: ModelContext) {
        try? context.save()
    }
}
