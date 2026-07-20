import SwiftData
import SwiftUI

struct ItemPickerSheet: View {
    @Binding var selectedItem: GroceryItem?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GroceryItem.name) private var items: [GroceryItem]
    @State private var searchText = ""

    private var filteredItems: [GroceryItem] {
        guard !searchText.isEmpty else { return items }
        let query = searchText.lowercased()
        return items.filter { item in
            item.name.lowercased().contains(query)
                || item.aliases.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if selectedItem != nil {
                    Button("Clear selection", role: .destructive) {
                        selectedItem = nil
                        dismiss()
                    }
                }
                ForEach(filteredItems) { item in
                    Button {
                        selectedItem = item
                        dismiss()
                    } label: {
                        LabeledContent {
                            Text(item.goodPricePer100g, format: .currency(code: "CAD"))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } label: {
                            Text(item.name)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search items")
            .navigationTitle("Choose item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
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
    return ItemPickerSheet(selectedItem: .constant(nil))
        .modelContainer(container)
}
