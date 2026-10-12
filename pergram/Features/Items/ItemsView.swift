import SwiftData
import SwiftUI

struct ItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.name) private var allItems: [GroceryItem]
    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @State private var searchText = ""
    @State private var isAdding = false
    @State private var addingName = ""
    @State private var editingItem: GroceryItem?
    /// Made from the dictionary just to open the sheet; removed again if the shopper cancels.
    @State private var provisionalItem: GroceryItem?
    @State private var renamingItem: GroceryItem?
    @State private var isRenaming = false
    @State private var renameText = ""

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
    private var massUnit: MeasureUnit {
        PriceDisplay.displayUnit(for: .mass, preferred: storedUnit)
    }

    private var priced: [GroceryItem] { filter(allItems) }
    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Everything else the search finds — dictionary entries, and items with no good price yet — so
    /// any grocery can be given one from here.
    private var unpriced: [ItemSearchResult] {
        ItemSearch.results(for: query, items: allItems).filter { result in
            if case .item(let item) = result { return !item.hasGoodPrice }
            return true
        }
    }

    private var canAddQuery: Bool {
        guard !query.isEmpty else { return false }
        return !ItemSearch.results(for: query, items: allItems).contains { $0.isNamed(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !priced.isEmpty {
                    Section {
                        ForEach(priced, content: row)
                    }
                }
                if !query.isEmpty && (!unpriced.isEmpty || canAddQuery) {
                    Section("Give a good price") {
                        ForEach(unpriced) { result in
                            Button {
                                giveGoodPrice(to: result)
                            } label: {
                                LabeledContent(result.name) {
                                    Image(systemName: "plus.circle")
                                }
                            }
                        }
                        if canAddQuery {
                            Button {
                                addingName = query
                                isAdding = true
                            } label: {
                                Label("Add “\(query)”", systemImage: "plus.circle")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search items")
            .navigationTitle("Items")
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
                        addingName = ""
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add item")
                    .accessibilityIdentifier("addItem")
                }
            }
            .overlay { emptyState }
        }
        .sheet(isPresented: $isAdding) {
            AddEditItemSheet(item: nil, initialName: addingName)
        }
        .sheet(item: $editingItem, onDismiss: discardProvisionalItem) { item in
            AddEditItemSheet(item: item)
        }
        .alert("Rename item", isPresented: $isRenaming) {
            TextField("Name", text: $renameText)
            Button("Save", action: commitRename)
            Button("Cancel", role: .cancel) { renamingItem = nil }
        }
    }

    private func row(_ item: GroceryItem) -> some View {
        Button {
            editingItem = item
        } label: {
            LabeledContent {
                Text(priceString(item))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } label: {
                Text(item.name)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            ForEach(item.goodPrices, id: \.dimension) { price in
                Button(role: .destructive) {
                    item.clearGoodPrice(for: price.dimension)
                    item.updatedAt = .now
                    try? modelContext.save()
                } label: {
                    Label(
                        "Remove \(PriceDisplay.formatted(price, in: PriceDisplay.displayUnit(for: price.dimension, preferred: storedUnit)))",
                        systemImage: "minus.circle")
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            Button {
                startRename(item)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.indigo)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if query.isEmpty && priced.isEmpty {
            ContentUnavailableView(
                "No good prices yet",
                systemImage: "tag",
                description: Text(
                    "Search for anything you buy to give it one, or check a price and save it.")
            )
        } else if priced.isEmpty && unpriced.isEmpty && !canAddQuery {
            ContentUnavailableView.search(text: searchText)
        }
    }

    private func priceString(_ item: GroceryItem) -> String {
        item.goodPriceSummary(preferring: storedUnit) ?? "No good price"
    }

    /// Only items with a good price: one used just for a list stays out of the way until it gets one.
    private func filter(_ items: [GroceryItem]) -> [GroceryItem] {
        let priced = items.filter(\.hasGoodPrice)
        guard !query.isEmpty else { return priced }
        let normalized = SearchText.normalize(query)
        return priced.filter { item in
            SearchText.score(
                query: normalized, terms: ([item.name] + item.aliases).map(SearchText.normalize))
                != nil
        }
    }

    /// Saved before presenting, so the sheet is keyed by a permanent identifier that a save inside
    /// it cannot change.
    private func giveGoodPrice(to result: ItemSearchResult) {
        switch result {
        case .item(let item):
            editingItem = item
        case .entry(let entry):
            let item = CatalogLibrary.item(for: entry, in: modelContext)
            if item.modelContext != nil, !item.hasGoodPrice, (item.listEntries ?? []).isEmpty {
                provisionalItem = item
            }
            try? modelContext.save()
            editingItem = item
        }
    }

    private func discardProvisionalItem() {
        defer { provisionalItem = nil }
        guard let item = provisionalItem, !item.hasGoodPrice, (item.listEntries ?? []).isEmpty,
            (item.cartEntries ?? []).isEmpty, (item.observations ?? []).isEmpty
        else { return }
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func startRename(_ item: GroceryItem) {
        renamingItem = item
        renameText = item.name
        isRenaming = true
    }

    private func commitRename() {
        guard let renamingItem else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            renamingItem.name = trimmed
            renamingItem.userModified = true
            renamingItem.updatedAt = .now
            try? modelContext.save()
        }
        self.renamingItem = nil
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
    container.mainContext.insert(
        GroceryItem(
            seedID: "eggs-large",
            name: "Eggs (large)",
            aliases: ["egg"],
            aisle: .dairy,
            goodPrice: NormalizedPrice(dimension: .count, canonical: 0.42)
        )
    )
    return ItemsView()
        .modelContainer(container)
}
