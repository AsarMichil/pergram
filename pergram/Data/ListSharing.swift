import Foundation
import SwiftData

@MainActor
enum ListSharing {
    static func payload(for list: GroceryList) -> ListPayload {
        ListPayload(
            id: list.id,
            name: list.name,
            entries: list.orderedEntries.map { entry in
                ListPayload.Entry(
                    id: entry.id,
                    text: entry.text,
                    isSkipped: entry.isSkipped,
                    item: entry.item.map { item in
                        ListPayload.Item(
                            seedID: item.seedID,
                            name: item.name,
                            aisle: item.category,
                            goodPrices: item.goodPrices.map {
                                ListPayload.GoodPrice(
                                    dimension: $0.dimension, canonical: $0.canonical)
                            }
                        )
                    }
                )
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

    struct ImportPlan {
        let payload: ListPayload
        let offers: [PriceOffer]
        let newItemNames: [String]
        let replacing: GroceryList?

        /// Offers that only fill a gap start accepted, since they overwrite nothing; offers that
        /// would replace one of your prices start declined.
        var initiallyAccepted: Set<OfferID> {
            Set(offers.filter { $0.yours == nil }.map(\.id))
        }
    }

    static func plan(_ payload: ListPayload, in context: ModelContext) -> ImportPlan {
        let catalog = (try? context.fetch(FetchDescriptor<GroceryItem>())) ?? []
        var offers: [PriceOffer] = []
        var newItemNames: [String] = []
        for incoming in uniqueItems(in: payload) {
            guard let match = match(incoming, in: catalog) else {
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
    /// merge a sync would do.
    @discardableResult
    static func apply(
        _ plan: ImportPlan,
        accepting accepted: Set<OfferID>,
        in context: ModelContext
    ) -> GroceryList {
        for offer in plan.offers where accepted.contains(offer.id) {
            offer.item.setGoodPrice(offer.theirs)
            offer.item.userModified = true
            offer.item.updatedAt = .now
        }

        var catalog = (try? context.fetch(FetchDescriptor<GroceryItem>())) ?? []
        let list = plan.replacing ?? insertList(id: plan.payload.id, in: context)
        list.name = plan.payload.name
        list.updatedAt = .now

        var existing = Dictionary(
            (list.entries ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (position, incoming) in plan.payload.entries.enumerated() {
            let entry =
                existing.removeValue(forKey: incoming.id) ?? insertEntry(incoming.id, in: list)
            entry.text = incoming.text
            entry.isSkipped = incoming.isSkipped
            entry.position = position
            entry.item = incoming.item.map { resolve($0, in: &catalog, context: context) }
        }
        for orphan in existing.values {
            context.delete(orphan)
        }
        try? context.save()
        return list
    }

    private static func uniqueItems(in payload: ListPayload) -> [ListPayload.Item] {
        var seen = Set<String>()
        return payload.entries.compactMap(\.item).filter { seen.insert(key(for: $0)).inserted }
    }

    private static func key(for item: ListPayload.Item) -> String {
        item.seedID.isEmpty ? "name:" + normalized(item.name) : "seed:" + item.seedID
    }

    /// The seed slug is identity when both sides have one; otherwise the name is all there is.
    private static func match(
        _ incoming: ListPayload.Item, in catalog: [GroceryItem]
    )
        -> GroceryItem?
    {
        if !incoming.seedID.isEmpty,
            let bySeed = catalog.first(where: { $0.seedID == incoming.seedID })
        {
            return bySeed
        }
        let name = normalized(incoming.name)
        return catalog.first { normalized($0.name) == name }
    }

    private static func resolve(
        _ incoming: ListPayload.Item, in catalog: inout [GroceryItem], context: ModelContext
    ) -> GroceryItem {
        if let match = match(incoming, in: catalog) { return match }
        let created = GroceryItem(
            seedID: incoming.seedID,
            name: incoming.name,
            aisle: Aisle(rawValue: incoming.aisle),
            userModified: incoming.seedID.isEmpty
        )
        prices(of: incoming).forEach(created.setGoodPrice)
        context.insert(created)
        catalog.append(created)
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

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

    private static func insertEntry(_ id: UUID, in list: GroceryList) -> ListEntry {
        let entry = ListEntry(id: id)
        list.modelContext?.insert(entry)
        entry.list = list
        return entry
    }
}
