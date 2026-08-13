import SwiftData
import SwiftUI

struct ItemPickerSheet: View {
    @Binding var selectedItemID: PersistentIdentifier?
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
                if selectedItemID != nil {
                    Button("Clear selection", role: .destructive) {
                        selectedItemID = nil
                        dismiss()
                    }
                }
                ForEach(filteredItems) { item in
                    Button {
                        selectedItemID = item.persistentModelID
                        dismiss()
                    } label: {
                        LabeledContent {
                            Text(
                                "\(item.goodPriceCanonical, format: .currency(code: "CAD"))\(PriceDisplay.suffix(for: MeasureUnit.canonicalUnit(for: item.dimension)))"
                            )
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
            seedID: "chicken-thigh-boneless",
            name: "Chicken thigh (boneless)",
            aliases: ["thighs"],
            category: "meat",
            goodPriceCanonical: 1.10
        )
    )
    return ItemPickerSheet(selectedItemID: .constant(nil))
        .modelContainer(container)
}
