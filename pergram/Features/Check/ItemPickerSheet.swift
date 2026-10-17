import SwiftData
import SwiftUI

/// Search first: the shopper's items and the bundled dictionary answer the same query, and anything
/// neither knows is one "Add" away. With nothing typed it shows only the shopper's own items — the
/// dictionary is too long to browse and is not meant to be.
struct ItemPickerSheet: View {
    @Binding var selectedItemID: PersistentIdentifier?
    var listEntries: [ListEntry] = []
    var canClear = true
    /// Set when the pick is for saving this price as the item's good price rather than checking
    /// against one.
    var goodPrice: NormalizedPrice?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.name) private var items: [GroceryItem]
    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @State private var searchText = ""

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
    private var showsClear: Bool { canClear && goodPrice == nil && selectedItemID != nil }

    private var goodPriceSubtitle: String {
        guard let goodPrice else { return "" }
        let unit = PriceDisplay.displayUnit(for: goodPrice.dimension, preferred: storedUnit)
        return PriceDisplay.formatted(goodPrice, in: unit)
    }
    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var results: [ItemSearchResult] { ItemSearch.results(for: query, items: items) }

    private var matchingListEntries: [ListEntry] {
        guard !query.isEmpty else { return listEntries }
        let normalized = SearchText.normalize(query)
        return listEntries.filter { SearchText.normalize($0.name).contains(normalized) }
    }

    /// Offered unless the query already names something exactly, which would only make a duplicate.
    private var canAddQuery: Bool {
        guard !query.isEmpty else { return false }
        return !results.contains { $0.isNamed(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if showsClear && query.isEmpty {
                    Button("Clear selection", role: .destructive) {
                        selectedItemID = nil
                        dismiss()
                    }
                }
                if !matchingListEntries.isEmpty {
                    Section("On your list") {
                        ForEach(matchingListEntries) { entry in
                            Button {
                                selectedItemID = entry.item?.persistentModelID
                                dismiss()
                            } label: {
                                Label(entry.name, systemImage: "circle")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                if query.isEmpty {
                    Section("Your items") {
                        ForEach(items) { item in
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
            .navigationTitle(goodPrice == nil ? "Choose item" : "Save good price")
            .navigationSubtitle(goodPriceSubtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if query.isEmpty && items.isEmpty && matchingListEntries.isEmpty {
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
                select(result.item(in: modelContext))
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
        dismiss()
    }

    private func addQuery() {
        select(ItemIdentity.item(named: query, in: modelContext))
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
