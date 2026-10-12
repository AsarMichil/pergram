import Foundation
import SwiftData

@MainActor
enum CatalogLibrary {
    /// Loaded once from the bundle. A missing or broken file degrades to an empty dictionary rather
    /// than a crash: search then only finds the shopper's own items.
    nonisolated static let bundled: Catalog = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let catalog = try? Catalog.decode(from: data)
        else {
            assertionFailure("catalog.json is missing or invalid")
            return .empty
        }
        return catalog
    }()

    /// The shopper's item for an entry, created on first use with no good price.
    static func item(
        for entry: CatalogEntry, in context: ModelContext
    ) -> GroceryItem {
        let id = entry.id
        var descriptor = FetchDescriptor<GroceryItem>(predicate: #Predicate { $0.seedID == id })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first { return existing }
        let item = GroceryItem(
            seedID: entry.id, name: entry.name, aliases: entry.aliases, aisle: entry.aisle)
        context.insert(item)
        return item
    }

    /// The shopper's own item named exactly `text`, else the dictionary's, created if need be.
    static func exactItem(
        named text: String, among items: [GroceryItem], catalog: Catalog = bundled,
        in context: ModelContext
    ) -> GroceryItem? {
        let query = SearchText.normalize(text)
        if let own = items.first(where: { item in
            ([item.name] + item.aliases).contains { SearchText.normalize($0) == query }
        }) {
            return own
        }
        return catalog.exactMatch(for: text).map { item(for: $0, in: context) }
    }
}

/// One row of a search over the shopper's items and the dictionary together.
enum ItemSearchResult: Identifiable {
    case item(GroceryItem)
    case entry(CatalogEntry)

    var id: String {
        switch self {
        case .item(let item): return "item-\(item.persistentModelID)"
        case .entry(let entry): return "entry-\(entry.id)"
        }
    }

    var name: String {
        switch self {
        case .item(let item): return item.name
        case .entry(let entry): return entry.name
        }
    }

    /// Whether the text is this result's name or one of its aliases, ignoring case and accents.
    func isNamed(_ text: String) -> Bool {
        let query = SearchText.normalize(text)
        let terms: [String]
        switch self {
        case .item(let item): terms = [item.name] + item.aliases
        case .entry(let entry): terms = entry.terms
        }
        return terms.contains { SearchText.normalize($0) == query }
    }
}

@MainActor
enum ItemSearch {
    /// The shopper's items rank ahead of dictionary entries that match as well, and an entry they
    /// already have an item for appears once, as their item.
    static func results(
        for text: String, items: [GroceryItem], catalog: Catalog = CatalogLibrary.bundled,
        limit: Int = 30
    ) -> [ItemSearchResult] {
        let query = SearchText.normalize(text)
        guard !query.isEmpty else { return [] }
        var scored: [(result: ItemSearchResult, score: Int)] = []
        for item in items {
            let terms = ([item.name] + item.aliases).map(SearchText.normalize)
            if let score = SearchText.score(query: query, terms: terms) {
                scored.append((.item(item), score * 2))
            }
        }
        let ownedIDs = Set(items.map(\.seedID).filter { !$0.isEmpty })
        for entry in catalog.search(text, limit: limit) where !ownedIDs.contains(entry.id) {
            let terms = entry.terms.map(SearchText.normalize)
            if let score = SearchText.score(query: query, terms: terms) {
                scored.append((.entry(entry), score * 2 + 1))
            }
        }
        scored.sort { lhs, rhs in
            lhs.score != rhs.score
                ? lhs.score < rhs.score : lhs.result.name.count < rhs.result.name.count
        }
        return scored.prefix(limit).map(\.result)
    }
}
