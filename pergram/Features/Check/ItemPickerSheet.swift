import SwiftData
import SwiftUI

struct ItemPickerSheet: View {
    @Binding var selectedItemID: PersistentIdentifier?
    var selectedListEntryID: Binding<UUID?> = .constant(nil)
    var listEntries: [ListEntry] = []
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

    private var filteredListEntries: [ListEntry] {
        guard !searchText.isEmpty else { return listEntries }
        let query = searchText.lowercased()
        return listEntries.filter { $0.text.lowercased().contains(query) }
    }

    private var hasSelection: Bool {
        selectedItemID != nil || selectedListEntryID.wrappedValue != nil
    }

    var body: some View {
        NavigationStack {
            List {
                if hasSelection {
                    Button("Clear selection", role: .destructive) {
                        selectedItemID = nil
                        selectedListEntryID.wrappedValue = nil
                        dismiss()
                    }
                }
                if !filteredListEntries.isEmpty {
                    Section("On your list") {
                        ForEach(filteredListEntries) { entry in
                            Button {
                                selectedItemID = entry.item?.persistentModelID
                                selectedListEntryID.wrappedValue = entry.id
                                dismiss()
                            } label: {
                                Label(entry.text, systemImage: "circle")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                Section {
                    ForEach(filteredItems) { item in
                        Button {
                            selectedItemID = item.persistentModelID
                            selectedListEntryID.wrappedValue = nil
                            dismiss()
                        } label: {
                            LabeledContent {
                                Text(item.goodPriceSummary(preferring: .per100Grams) ?? "")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            } label: {
                                Text(item.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                } header: {
                    if !filteredListEntries.isEmpty { Text("All items") }
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
                if filteredItems.isEmpty && filteredListEntries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
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
    return ItemPickerSheet(selectedItemID: .constant(nil))
        .modelContainer(container)
}
