import SwiftData
import SwiftUI

struct AppTabView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Check", systemImage: "checkmark.circle") {
                CheckView()
            }
            Tab("Scan", systemImage: "camera.viewfinder") {
                ScanView()
            }
            Tab("Items", systemImage: "cart") {
                ItemsView()
            }
            Tab("Help", systemImage: "questionmark.circle") {
                HelpView()
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
    let container = try! ModelContainer(
        for: GroceryItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(
        GroceryItem(
            id: "chicken-thigh-boneless",
            name: "Chicken thigh (boneless)",
            aliases: ["thighs"],
            category: "meat",
            goodPricePer100g: 1.10
        )
    )
    return AppTabView()
        .modelContainer(container)
}
