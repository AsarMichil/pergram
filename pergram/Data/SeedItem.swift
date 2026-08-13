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
    let dimension: PriceDimension?

    func makeModel() -> GroceryItem {
        GroceryItem(
            seedID: id,
            name: name,
            aliases: aliases,
            category: category,
            goodPriceCanonical: goodPricePer100g,
            dimension: dimension ?? .mass,
            userModified: false,
            updatedAt: .now
        )
    }
}
