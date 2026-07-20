import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.name) private var items: [GroceryItem]

    var body: some View {
        NavigationStack {
            List(items) { item in
                LabeledContent {
                    Text(item.goodPricePer100g, format: .currency(code: "CAD"))
                        .monospacedDigit()
                } label: {
                    Text(item.name)
                }
            }
            .navigationTitle("PerGram")
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No items yet",
                        systemImage: "cart",
                        description: Text("Check a price and save it.")
                    )
                }
            }
        }
        .task { importSeedIfNeeded() }
    }

    private func importSeedIfNeeded() {
        let defaults = UserDefaults.standard
        let currentVersion = defaults.integer(forKey: SeedImporter.versionDefaultsKey)
        do {
            let seed = try SeedImporter.loadBundledSeed()
            let newVersion = try SeedImporter.importMissingItems(
                from: seed,
                into: modelContext,
                currentVersion: currentVersion
            )
            if newVersion != currentVersion {
                defaults.set(newVersion, forKey: SeedImporter.versionDefaultsKey)
            }
        } catch {
            assertionFailure("Seed import failed: \(error)")
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: GroceryItem.self, inMemory: true)
}
