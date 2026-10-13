import Foundation
import SwiftData

@MainActor
enum ListSharing {
    static func payload(for list: GroceryList) -> ListPayload {
        ListPayload(
            id: list.id,
            name: list.name,
            entries: list.orderedEntries.compactMap { entry in
                entry.item.map { item in
                    ListPayload.Entry(
                        id: entry.id,
                        isSkipped: entry.isSkipped,
                        note: entry.note,
                        item: ListPayload.Item(
                            seedID: item.seedID,
                            name: item.name,
                            aisle: item.category,
                            goodPrices: item.goodPrices.map {
                                ListPayload.GoodPrice(
                                    dimension: $0.dimension, canonical: $0.canonical)
                            }
                        )
                    )
                }
            }
        )
    }

    struct OfferID: Hashable {
        let item: PersistentIdentifier
        let dimension: PriceDimension
    }

    /// The sender's good price for an item the receiver already has, in one dimension. Never applied
    /// unless accepted: an incoming list must not quietly rewrite your baselines.
    struct PriceOffer: Identifiable {
        let item: GroceryItem
        let theirs: NormalizedPrice

        var id: OfferID { OfferID(item: item.persistentModelID, dimension: theirs.dimension) }
        /// `nil` when the offer fills a gap rather than replacing a price.
        var yours: NormalizedPrice? { item.goodPrice(for: theirs.dimension) }
    }

    struct ListChanges {
        let added: [String]
        let removed: [String]
        let nowSkipped: [String]
        let nowNeeded: [String]

        var isEmpty: Bool {
            added.isEmpty && removed.isEmpty && nowSkipped.isEmpty && nowNeeded.isEmpty
        }
    }

    struct ImportPlan {
        let payload: ListPayload
        let offers: [PriceOffer]
        let newItemNames: [String]
        let replacing: GroceryList?

        /// What an update would do to the list already here; `nil` when there is none.
        var changes: ListChanges? {
            guard let replacing else { return nil }
            let mine = Dictionary(
                (replacing.entries ?? []).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first })
            let theirs = Set(payload.entries.map(\.id))
            return ListChanges(
                added: payload.entries.filter { mine[$0.id] == nil }.map(\.item.name),
                removed: mine.values.filter { !theirs.contains($0.id) }.map(\.name).sorted(),
                nowSkipped: payload.entries.filter { incoming in
                    incoming.isSkipped && mine[incoming.id].map { !$0.isSkipped } == true
                }.map(\.item.name),
                nowNeeded: payload.entries.filter { incoming in
                    !incoming.isSkipped && mine[incoming.id]?.isSkipped == true
                }.map(\.item.name)
            )
        }

        /// Offers that only fill a gap start accepted, since they overwrite nothing; offers that
        /// would replace one of your prices start declined.
        var initiallyAccepted: Set<OfferID> {
            Set(offers.filter { $0.yours == nil }.map(\.id))
        }
    }

    static func plan(_ payload: ListPayload, in context: ModelContext) -> ImportPlan {
        var offers: [PriceOffer] = []
        var newItemNames: [String] = []
        for incoming in uniqueItems(in: payload) {
            guard let match = match(incoming, in: context) else {
                newItemNames.append(incoming.name)
                continue
            }
            offers += prices(of: incoming)
                .filter { differs(match.goodPrice(for: $0.dimension), from: $0) }
                .map { PriceOffer(item: match, theirs: $0) }
        }
        return ImportPlan(
            payload: payload,
            offers: offers,
            newItemNames: newItemNames,
            replacing: list(withID: payload.id, in: context)
        )
    }

    /// A list already here under the same `id` is updated in place, entry by entry, which is the same
    /// merge a sync would do. `asCopy` instead makes an unrelated list with fresh ids, so later shares
    /// of the original keep updating the original and leave the copy alone.
    @discardableResult
    static func apply(
        _ plan: ImportPlan,
        accepting accepted: Set<OfferID>,
        asCopy: Bool = false,
        in context: ModelContext
    ) -> GroceryList {
        for offer in plan.offers where accepted.contains(offer.id) {
            offer.item.setGoodPrice(offer.theirs)
            context.insert(
                PriceObservation(price: offer.theirs, reason: .goodPrice, item: offer.item))
            offer.item.userModified = true
            offer.item.updatedAt = .now
        }

        let target = asCopy ? nil : plan.replacing
        let list = target ?? insertList(id: asCopy ? UUID() : plan.payload.id, in: context)
        list.name = asCopy ? "\(plan.payload.name) (copy)" : plan.payload.name
        list.updatedAt = .now

        var existing = Dictionary(
            (list.entries ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (position, incoming) in plan.payload.entries.enumerated() {
            let item = resolve(incoming.item, in: context)
            let entry: ListEntry
            if let mine = existing.removeValue(forKey: incoming.id) {
                mine.item = item
                entry = mine
            } else {
                let wasOnList = (list.entries ?? []).contains { $0.item === item }
                entry = list.add(item)
                existing.removeValue(forKey: entry.id)
                // A new entry takes the sender's id, so their next share updates it in place.
                if !wasOnList, !asCopy { entry.id = incoming.id }
            }
            entry.isSkipped = incoming.isSkipped
            entry.note = incoming.note
            entry.position = position
        }
        for orphan in existing.values {
            context.delete(orphan)
        }
        try? context.save()
        StoreUpkeep.prune(in: context)
        return list
    }

    private static func uniqueItems(in payload: ListPayload) -> [ListPayload.Item] {
        var seen = Set<String>()
        return payload.entries.map(\.item).filter { seen.insert(key(for: $0)).inserted }
    }

    private static func key(for item: ListPayload.Item) -> String {
        item.seedID.isEmpty ? "name:" + SearchText.normalize(item.name) : "seed:" + item.seedID
    }

    /// The seed slug is identity when both sides have one; otherwise the name is all there is, matched
    /// the way typed text is.
    private static func match(
        _ incoming: ListPayload.Item, in context: ModelContext
    )
        -> GroceryItem?
    {
        if !incoming.seedID.isEmpty {
            let seedID = incoming.seedID
            var descriptor = FetchDescriptor<GroceryItem>(
                predicate: #Predicate { $0.seedID == seedID })
            descriptor.fetchLimit = 1
            if let bySeed = try? context.fetch(descriptor).first { return bySeed }
        }
        return ItemIdentity.existing(named: incoming.name, in: context)
    }

    private static func resolve(
        _ incoming: ListPayload.Item, in context: ModelContext
    )
        -> GroceryItem
    {
        if let match = match(incoming, in: context) { return match }
        let created = GroceryItem(
            seedID: incoming.seedID,
            name: incoming.name,
            aisle: Aisle(rawValue: incoming.aisle),
            userModified: incoming.seedID.isEmpty
        )
        context.insert(created)
        for price in prices(of: incoming) {
            created.setGoodPrice(price)
            context.insert(PriceObservation(price: price, reason: .goodPrice, item: created))
        }
        return created
    }

    /// Below a cent the two prices read the same on screen, so offering one would ask a question
    /// with no visible difference.
    private static func differs(_ yours: NormalizedPrice?, from theirs: NormalizedPrice) -> Bool {
        guard let yours else { return true }
        return abs(yours.canonical - theirs.canonical) >= 0.005
    }

    private static func prices(of incoming: ListPayload.Item) -> [NormalizedPrice] {
        incoming.goodPrices
            .filter { $0.canonical > 0 }
            .map { NormalizedPrice(dimension: $0.dimension, canonical: $0.canonical) }
    }

    private static func list(withID id: UUID, in context: ModelContext) -> GroceryList? {
        var descriptor = FetchDescriptor<GroceryList>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func insertList(id: UUID, in context: ModelContext) -> GroceryList {
        let list = GroceryList(id: id)
        context.insert(list)
        return list
    }
}
