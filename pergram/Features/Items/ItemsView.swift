import SwiftData
import SwiftUI

/// Everything the shopper buys, whether or not it has a good price yet — a good price is something
/// an item has, not a different kind of item. Search reaches the dictionary too, so anything can be
/// added from here.
struct ItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.name) private var items: [GroceryItem]
    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @State private var searchText = ""
    @State private var isAdding = false
    @State private var editingItem: GroceryItem?
    @State private var deletingItem: GroceryItem?

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
    private var massUnit: MeasureUnit {
        PriceDisplay.displayUnit(for: .mass, preferred: storedUnit)
    }

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var results: [ItemSearchResult] { ItemSearch.results(for: query, items: items) }

    private var canAddQuery: Bool {
        !query.isEmpty && !results.contains { $0.isNamed(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    ForEach(AisleOrder.standard.sorted(items) { $0.aisle ?? .other }, id: \.aisle) {
                        group in
                        Section(group.aisle.title) {
                            ForEach(group.elements, content: row)
                        }
                    }
                } else {
                    Section {
                        ForEach(results) { result in
                            switch result {
                            case .item(let item):
                                row(item)
                            case .entry(let entry):
                                Button {
                                    edit(result.item(in: modelContext))
                                } label: {
                                    LabeledContent(entry.name) {
                                        Text(entry.aisle.title)
                                    }
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                        if canAddQuery {
                            Button {
                                edit(ItemIdentity.item(named: query, in: modelContext))
                            } label: {
                                Label("Add “\(query)”", systemImage: "plus.circle")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search items")
            .navigationTitle("Your items")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        displayUnitRaw = PriceDisplay.next(after: massUnit, in: .mass).rawValue
                    } label: {
                        Text(PriceDisplay.suffix(for: massUnit))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .sensoryFeedback(.selection, trigger: displayUnitRaw)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a good price")
                    .accessibilityIdentifier("addItem")
                }
            }
            .overlay { emptyState }
        }
        .sheet(isPresented: $isAdding) {
            AddEditItemSheet(item: nil)
        }
        .sheet(item: $editingItem, onDismiss: { StoreUpkeep.prune(in: modelContext) }) { item in
            ItemForm(item: item)
        }
        .confirmationDialog(
            deletingItem.map { "Delete \($0.name)?" } ?? "",
            isPresented: Binding(
                get: { deletingItem != nil }, set: { if !$0 { deletingItem = nil } }),
            titleVisibility: .visible,
            presenting: deletingItem
        ) { item in
            Button("Delete", role: .destructive) { delete(item) }
        } message: { item in
            Text("Also removes it from \(listNames(of: item)).")
        }
    }

    private func row(_ item: GroceryItem) -> some View {
        Button {
            edit(item)
        } label: {
            LabeledContent {
                if let summary = item.goodPriceSummary(preferring: storedUnit) {
                    Text(summary)
                        .monospacedDigit()
                } else {
                    Text("Set good price")
                        .foregroundStyle(.tertiary)
                }
            } label: {
                Text(item.name)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if (item.listEntries ?? []).isEmpty {
                    delete(item)
                } else {
                    deletingItem = item
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if query.isEmpty && items.isEmpty {
            ContentUnavailableView(
                "Nothing here yet",
                systemImage: "tag",
                description: Text(
                    "What you add to a list or give a good price shows up here. Search to add anything."
                )
            )
        } else if !query.isEmpty && results.isEmpty && !canAddQuery {
            ContentUnavailableView.search(text: searchText)
        }
    }

    /// Saved before presenting, so the sheet is keyed by a permanent identifier that a save inside
    /// it cannot change.
    private func edit(_ item: GroceryItem) {
        try? modelContext.save()
        editingItem = item
    }

    private func delete(_ item: GroceryItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func listNames(of item: GroceryItem) -> String {
        let names = (item.listEntries ?? []).compactMap { $0.list?.name }
        return ListFormatter.localizedString(byJoining: Array(Set(names)).sorted())
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
            goodPrice: NormalizedPrice(dimension: .mass, canonical: 1.10),
            userModified: true
        )
    )
    container.mainContext.insert(GroceryItem(name: "Paper towels", aisle: .household))
    return ItemsView()
        .modelContainer(container)
}
