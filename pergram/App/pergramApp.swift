import SwiftData
import SwiftUI

@main
struct PergramApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([GroceryItem.self, PriceObservation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppTabView()
        }
        .modelContainer(modelContainer)
    }
}
