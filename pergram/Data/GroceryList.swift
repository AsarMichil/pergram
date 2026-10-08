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

    @discardableResult
    func append(_ text: String, item: GroceryItem? = nil) -> ListEntry {
        let entry = ListEntry(text: text, position: (orderedEntries.last?.position ?? -1) + 1)
        entry.item = item
        entry.list = self
        updatedAt = .now
        return entry
    }
}

@Model
final class ListEntry {
    var id: UUID = UUID()
    var text: String = ""
    var position: Int = 0
    /// "Not this time": kept across trips until cleared, so a reused list remembers what you are
    /// sitting out.
    var isSkipped: Bool = false
    var item: GroceryItem?
    var list: GroceryList?

    init(id: UUID = UUID(), text: String = "", position: Int = 0, isSkipped: Bool = false) {
        self.id = id
        self.text = text
        self.position = position
        self.isSkipped = isSkipped
    }
}
