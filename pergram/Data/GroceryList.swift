import Foundation
import SwiftData

/// `id` is the list's identity across devices: a re-shared copy updates the list it came from rather
/// than duplicating it. Not `.unique`, for the same CloudKit reason as `GroceryItem`.
@Model
final class GroceryList {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    @Relationship(deleteRule: .cascade, inverse: \ListEntry.list)
    var entries: [ListEntry]? = []

    @Relationship(deleteRule: .nullify, inverse: \Trip.list)
    var trips: [Trip]? = []

    init(id: UUID = UUID(), name: String = "", createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var orderedEntries: [ListEntry] {
        (entries ?? []).sorted { $0.position < $1.position }
    }

    /// A list holds each item once: adding one already on it brings that entry back into this
    /// shop rather than listing it twice.
    @discardableResult
    func add(_ item: GroceryItem) -> ListEntry {
        updatedAt = .now
        if let existing = entries?.first(where: { $0.item === item }) {
            existing.isSkipped = false
            return existing
        }
        let entry = ListEntry(position: (orderedEntries.last?.position ?? -1) + 1)
        entry.item = item
        entry.list = self
        return entry
    }
}

/// One of the shopper's items, on one list. What the item is — its name, aisle and good prices —
/// lives on the item; only what is about this list lives here.
@Model
final class ListEntry {
    var id: UUID = UUID()
    var position: Int = 0
    /// "Not this time": kept across trips until cleared, so a reused list remembers what you are
    /// sitting out.
    var isSkipped: Bool = false
    /// Free text for how many or which: "6", "2 lb", "ripe ones". Not a number, because grocery
    /// amounts mix units and nothing computes with them.
    var note: String?
    var item: GroceryItem?
    var list: GroceryList?

    init(id: UUID = UUID(), position: Int = 0, isSkipped: Bool = false) {
        self.id = id
        self.position = position
        self.isSkipped = isSkipped
    }

    var name: String { item?.name ?? "" }
    var aisle: Aisle { item?.aisle ?? .other }
}
