import SwiftData
import SwiftUI

struct ItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<GroceryItem> { $0.userModified }, sort: \GroceryItem.name)
    private var yours: [GroceryItem]
    @Query(filter: #Predicate<GroceryItem> { !$0.userModified }, sort: \GroceryItem.name)
    private var suggested: [GroceryItem]

    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @State private var searchText = ""
    @State private var isAdding = false
    @State private var editingItem: GroceryItem?
    @State private var renamingItem: GroceryItem?
    @State private var isRenaming = false
    @State private var renameText = ""

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
    private var massUnit: MeasureUnit {
        PriceDisplay.displayUnit(for: .mass, preferred: storedUnit)
    }

    private var filteredYours: [GroceryItem] { filter(yours) }
    private var filteredSuggested: [GroceryItem] { filter(suggested) }

    var body: some View {
        NavigationStack {
            List {
                if !filteredYours.isEmpty {
                    Section("Yours") {
                        ForEach(filteredYours, content: row)
                    }
                }
                if !filteredSuggested.isEmpty {
                    Section("Suggested") {
                        ForEach(filteredSuggested, content: row)
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
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay { emptyState }
        }
        .sheet(isPresented: $isAdding) {
            AddEditItemSheet(item: nil)
        }
        .sheet(item: $editingItem) { item in
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
        if yours.isEmpty && suggested.isEmpty {
            ContentUnavailableView(
                "No items yet",
                systemImage: "cart",
                description: Text("Add one with +, or check a price and save it.")
            )
        } else if filteredYours.isEmpty && filteredSuggested.isEmpty {
            ContentUnavailableView.search(text: searchText)
        }
    }

    private func priceString(_ item: GroceryItem) -> String {
        let price = NormalizedPrice(dimension: item.dimension, canonical: item.goodPriceCanonical)
        let unit = PriceDisplay.displayUnit(for: item.dimension, preferred: storedUnit)
        let value = PriceDisplay.value(price, in: unit)
        return value.formatted(.currency(code: "CAD")) + PriceDisplay.suffix(for: unit)
    }

    private func filter(_ items: [GroceryItem]) -> [GroceryItem] {
        guard !searchText.isEmpty else { return items }
        let query = searchText.lowercased()
        return items.filter { item in
            item.name.lowercased().contains(query)
                || item.aliases.contains { $0.lowercased().contains(query) }
        }
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
        for: GroceryItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(
        GroceryItem(
            seedID: "chicken-thigh-boneless",
            name: "Chicken thigh (boneless)",
            aliases: ["thighs"],
            category: "meat",
            goodPriceCanonical: 1.10,
            userModified: true
        )
    )
    container.mainContext.insert(
        GroceryItem(
            seedID: "eggs-large",
            name: "Eggs (large)",
            aliases: ["egg"],
            category: "dairy",
            goodPriceCanonical: 0.42,
            dimension: .count
        )
    )
    return ItemsView()
        .modelContainer(container)
}
