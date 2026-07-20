import Foundation
import SwiftData
import Testing

@testable import pergram

@MainActor
struct SeedImporterTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([GroceryItem.self, PriceObservation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func seed(version: Int, ids: [String], price: Double = 1.00) -> SeedFile {
        let items = ids.map {
            SeedItem(id: $0, name: $0, aliases: [], category: "test", goodPricePer100g: price)
        }
        return SeedFile(seedVersion: version, items: items)
    }

    private func allItems(_ context: ModelContext) throws -> [GroceryItem] {
        try context.fetch(FetchDescriptor<GroceryItem>())
    }

    @Test func freshImportInsertsAllItems() throws {
        let context = try makeContext()
        let newVersion = try SeedImporter.importMissingItems(
            from: seed(version: 1, ids: ["a", "b", "c"]),
            into: context,
            currentVersion: 0
        )
        #expect(newVersion == 1)
        #expect(try allItems(context).count == 3)
    }

    @Test func reimportOfSameVersionIsNoOp() throws {
        let context = try makeContext()
        let file = seed(version: 1, ids: ["a", "b"])
        _ = try SeedImporter.importMissingItems(from: file, into: context, currentVersion: 0)
        let version = try SeedImporter.importMissingItems(
            from: file, into: context, currentVersion: 1)
        #expect(version == 1)
        #expect(try allItems(context).count == 2)
    }

    @Test func userModifiedPriceSurvivesVersionBump() throws {
        let context = try makeContext()
        _ = try SeedImporter.importMissingItems(
            from: seed(version: 1, ids: ["a"], price: 1.00),
            into: context,
            currentVersion: 0
        )

        let item = try #require(try allItems(context).first { $0.id == "a" })
        item.goodPricePer100g = 0.42
        item.userModified = true
        try context.save()

        let bumped = SeedFile(
            seedVersion: 2,
            items: [
                SeedItem(id: "a", name: "a", aliases: [], category: "test", goodPricePer100g: 9.99),
                SeedItem(id: "b", name: "b", aliases: [], category: "test", goodPricePer100g: 1.00),
            ]
        )
        let version = try SeedImporter.importMissingItems(
            from: bumped, into: context, currentVersion: 1)

        #expect(version == 2)
        let reloaded = try #require(try allItems(context).first { $0.id == "a" })
        #expect(reloaded.goodPricePer100g == 0.42)
        #expect(reloaded.userModified)
        #expect(try allItems(context).count == 2)
    }

    @Test func decodesSeedJSON() throws {
        let json = """
            { "seedVersion": 3, "items": [
              { "id": "x", "name": "X", "aliases": ["y"], "category": "c", "goodPricePer100g": 1.5 }
            ] }
            """
        let file = try SeedFile.decode(from: Data(json.utf8))
        #expect(file.seedVersion == 3)
        #expect(file.items.first?.goodPricePer100g == 1.5)
    }
}
