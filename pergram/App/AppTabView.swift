import SwiftData
import SwiftUI

struct AppTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Check", systemImage: "checkmark.circle", value: AppTab.check) {
                CheckView()
            }
            Tab("Lists", systemImage: "checklist", value: AppTab.lists) {
                ListsView()
            }
            // `tag`, not `cart`: the cart is the Shop page's.
            Tab("Items", systemImage: "tag", value: AppTab.items) {
                ItemsView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            LegacyGoodPriceMigration.run(in: modelContext)
            importSeedIfNeeded()
        }
        .sheet(item: $router.incomingList) { incoming in
            ImportListSheet(incoming: incoming) { _ in router.tab = .lists }
        }
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
        for: AppSchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(
        GroceryItem(
            seedID: "chicken-thigh-boneless",
            name: "Chicken thigh (boneless)",
            aliases: ["thighs"],
            aisle: .meat,
            goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10)
        )
    )
    return AppTabView()
        .modelContainer(container)
        .environment(AppRouter())
}
