import SwiftData
import SwiftUI

struct AppTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection = 0

    private static let tabCount = 4

    var body: some View {
        TabView(selection: $selection) {
            Tab("Check", systemImage: "checkmark.circle", value: 0) {
                CheckView()
            }
            Tab("Scan", systemImage: "camera.viewfinder", value: 1) {
                ScanView()
            }
            Tab("Items", systemImage: "cart", value: 2) {
                ItemsView()
            }
            Tab("Help", systemImage: "questionmark.circle", value: 3) {
                HelpView()
            }
        }
        .simultaneousGesture(swipeBetweenTabs)
        .task { importSeedIfNeeded() }
    }

    private var swipeBetweenTabs: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) * 1.5,
                    abs(horizontal) > 60
                else { return }
                let next = horizontal < 0 ? selection + 1 : selection - 1
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selection = min(max(next, 0), Self.tabCount - 1)
                }
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
