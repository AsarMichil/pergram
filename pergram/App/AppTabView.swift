import SwiftData
import SwiftUI

struct AppTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppTab = .check
    @State private var isBarExpanded = true
    @State private var idleTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            CheckView()
                .opacity(selection == .check ? 1 : 0)
                .allowsHitTesting(selection == .check)
            ItemsView()
                .opacity(selection == .items ? 1 : 0)
                .allowsHitTesting(selection == .items)
            SettingsView()
                .opacity(selection == .settings ? 1 : 0)
                .allowsHitTesting(selection == .settings)
        }
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selection: $selection, isExpanded: isBarExpanded, onActivity: nudgeIdle)
        }
        .task {
            importSeedIfNeeded()
            nudgeIdle()
        }
    }

    /// Any tab-bar interaction expands the bar and restarts the idle timer; after a few seconds
    /// with no bar interaction it minimizes to reclaim height for the content.
    private func nudgeIdle() {
        idleTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { isBarExpanded = true }
        idleTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { isBarExpanded = false }
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
