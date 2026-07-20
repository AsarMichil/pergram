import SwiftData
import SwiftUI

struct ItemsView: View {
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
            .navigationTitle("Items")
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
    return ItemsView()
        .modelContainer(container)
}
