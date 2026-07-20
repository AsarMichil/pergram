import Foundation
import SwiftData

enum SeedImportError: Error {
    case missingBundleResource
}

@MainActor
enum SeedImporter {
    static let versionDefaultsKey = "seedVersion"

    static func loadBundledSeed(from bundle: Bundle = .main) throws -> SeedFile {
        guard let url = bundle.url(forResource: "seed", withExtension: "json") else {
            throw SeedImportError.missingBundleResource
        }
        return try SeedFile.decode(from: Data(contentsOf: url))
    }

    /// Inserts only items the user does not already have, and never touches an existing row, so a
    /// user's edited price survives every future seed. Idempotent: re-running inserts nothing.
    /// Returns the version the caller should persist.
    @discardableResult
    static func importMissingItems(
        from seed: SeedFile,
        into context: ModelContext,
        currentVersion: Int
    ) throws -> Int {
        guard seed.seedVersion > currentVersion else { return currentVersion }
        let existingIds = Set(try context.fetch(FetchDescriptor<GroceryItem>()).map(\.id))
        for item in seed.items where !existingIds.contains(item.id) {
            context.insert(item.makeModel())
        }
        try context.save()
        return seed.seedVersion
    }
}
