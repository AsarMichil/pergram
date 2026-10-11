import SwiftData
import SwiftUI

/// Search first: the shopper's items and the bundled dictionary answer the same query, and anything
/// neither knows is one "Add" away. With nothing typed it shows only what the shopper already uses —
/// the dictionary is too long to browse and is not meant to be.
struct ItemPickerSheet: View {
    @Binding var selectedItemID: PersistentIdentifier?
    var selectedListEntryID: Binding<UUID?> = .constant(nil)
    var listEntries: [ListEntry] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.name) private var items: [GroceryItem]
    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @State private var searchText = ""

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var pricedItems: [GroceryItem] { items.filter(\.hasGoodPrice) }

    private var results: [ItemSearchResult] { ItemSearch.results(for: query, items: items) }

    private var matchingListEntries: [ListEntry] {
        guard !query.isEmpty else { return listEntries }
        let normalized = SearchText.normalize(query)
        return listEntries.filter { SearchText.normalize($0.text).contains(normalized) }
    }

    /// Offered unless the query already names something exactly, which would only make a duplicate.
    private var canAddQuery: Bool {
        guard !query.isEmpty else { return false }
        return !results.contains { $0.isNamed(query) }
    }

    private var hasSelection: Bool {
        selectedItemID != nil || selectedListEntryID.wrappedValue != nil
    }

    var body: some View {
        NavigationStack {
            List {
                if hasSelection && query.isEmpty {
                    Button("Clear selection", role: .destructive) {
                        selectedItemID = nil
                        selectedListEntryID.wrappedValue = nil
                        dismiss()
                    }
                }
                if !matchingListEntries.isEmpty {
                    Section("On your list") {
                        ForEach(matchingListEntries) { entry in
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
                if query.isEmpty {
                    Section("Your items") {
                        ForEach(pricedItems) { item in
                            itemRow(
                                name: item.name,
                                detail: item.goodPriceSummary(preferring: storedUnit)
                            ) {
                                select(item)
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(results) { result in
                            row(for: result)
                        }
                        if canAddQuery {
                            Button {
                                addQuery()
                            } label: {
                                Label("Add “\(query)”", systemImage: "plus.circle")
                            }
                            .accessibilityIdentifier("addSearchedItem")
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search items"
            )
            .navigationTitle("Choose item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if query.isEmpty && pricedItems.isEmpty && matchingListEntries.isEmpty {
                    ContentUnavailableView(
                        "Search for an item",
                        systemImage: "magnifyingglass",
                        description: Text("Bananas, milk, paper towels — or anything you type.")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func row(for result: ItemSearchResult) -> some View {
        switch result {
        case .item(let item):
            itemRow(name: item.name, detail: item.goodPriceSummary(preferring: storedUnit)) {
                select(item)
            }
        case .entry(let entry):
            itemRow(name: entry.name, detail: entry.aisle.title) {
                select(CatalogLibrary.item(for: entry, in: modelContext))
            }
        }
    }

    private func itemRow(name: String, detail: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LabeledContent {
                if let detail {
                    Text(detail)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text(name)
                    .foregroundStyle(.primary)
            }
        }
    }

    private func select(_ item: GroceryItem) {
        try? modelContext.save()
        selectedItemID = item.persistentModelID
        selectedListEntryID.wrappedValue = nil
        dismiss()
    }

    private func addQuery() {
        let item = GroceryItem(
            name: query, aisle: CatalogLibrary.bundled.guessAisle(for: query), userModified: true)
        modelContext.insert(item)
        select(item)
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
