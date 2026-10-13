import Foundation

/// A grocery list as it travels between people. Every transport — a file over AirDrop, a link, a
/// sync server — carries this one payload, so a new way to share is never a new format.
///
/// Carries no crossed-off state: that belongs to one person's trip, not to the list.
nonisolated struct ListPayload: Codable, Equatable, Sendable {
    static let formatName = "pergram.list"
    static let currentVersion = 1

    struct Entry: Codable, Equatable, Sendable {
        let id: UUID
        let isSkipped: Bool
        var note: String? = nil
        let item: Item
    }

    /// The sender's catalog item, with their good prices, so the receiver can relink it or adopt it.
    struct Item: Codable, Equatable, Sendable {
        let seedID: String
        let name: String
        let aisle: String
        let goodPrices: [GoodPrice]
    }

    /// One good price, in its dimension's canonical unit.
    struct GoodPrice: Codable, Equatable, Sendable {
        let dimension: PriceDimension
        let canonical: Double
    }

    enum DecodingFailure: Error, Equatable {
        case notAList
        case newerVersion(Int)
    }

    let format: String
    let version: Int
    let id: UUID
    let name: String
    let entries: [Entry]

    init(id: UUID, name: String, entries: [Entry]) {
        format = Self.formatName
        version = Self.currentVersion
        self.id = id
        self.name = name
        self.entries = entries
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> ListPayload {
        let payload: ListPayload
        do {
            payload = try JSONDecoder().decode(ListPayload.self, from: data)
        } catch {
            throw DecodingFailure.notAList
        }
        guard payload.format == formatName else { throw DecodingFailure.notAList }
        guard payload.version <= currentVersion else {
            throw DecodingFailure.newerVersion(payload.version)
        }
        return payload
    }

    /// For apps that cannot open the file: a checklist anyone can read.
    var plainText: String {
        let lines = entries.map { entry in
            let line = [entry.item.name, entry.note].compactMap { $0 }.joined(separator: " — ")
            return entry.isSkipped ? "– \(line) (not this time)" : "☐ \(line)"
        }
        return ([name] + lines).joined(separator: "\n")
    }
}
