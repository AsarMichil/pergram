import Foundation

nonisolated struct SeedFile: Codable, Sendable {
    let seedVersion: Int
    let items: [SeedItem]

    static func decode(from data: Data) throws -> SeedFile {
        try JSONDecoder().decode(SeedFile.self, from: data)
    }
}

nonisolated struct SeedItem: Codable, Sendable {
    let id: String
    let name: String
    let aliases: [String]
    let category: String
    let goodPricePer100g: Double

    func makeModel() -> GroceryItem {
        GroceryItem(
            id: id,
            name: name,
            aliases: aliases,
            category: category,
            goodPricePer100g: goodPricePer100g,
            userModified: false,
            updatedAt: .now
        )
    }
}
