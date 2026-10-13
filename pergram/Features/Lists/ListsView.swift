import SwiftData
import SwiftUI

struct ListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryList.name) private var lists: [GroceryList]
    @State private var path: [GroceryList] = []
    @State private var isNaming = false
    @State private var newName = ""

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(lists) { list in
                    NavigationLink(value: list) {
                        LabeledContent(list.name) {
                            Text("\(list.entries?.count ?? 0)")
                                .monospacedDigit()
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(list)
                            try? modelContext.save()
                            StoreUpkeep.prune(in: modelContext)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Lists")
            .navigationDestination(for: GroceryList.self) { list in
                ListDetailView(list: list)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newName = ""
                        isNaming = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New list")
                    .accessibilityIdentifier("newList")
                }
            }
            .overlay {
                if lists.isEmpty {
                    ContentUnavailableView(
                        "No lists yet",
                        systemImage: "checklist",
                        description: Text("Make one with +, then shop it from Check.")
                    )
                }
            }
            .alert("New list", isPresented: $isNaming) {
                TextField("Name", text: $newName)
                Button("Create", action: create)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func create() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = GroceryList(name: trimmed.isEmpty ? "Groceries" : trimmed)
        modelContext.insert(list)
        try? modelContext.save()
        path = [list]
    }
}

struct ListDetailView: View {
    let list: GroceryList
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var items: [GroceryItem]
    @State private var newEntryText = ""
    @State private var editingEntry: ListEntry?
    @State private var isRenamingList = false
    @State private var listName = ""
    @State private var isPreparing = false
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        List {
            Section {
                TextField("Add an item", text: $newEntryText)
                    .focused($isAddFieldFocused)
                    .submitLabel(.next)
                    .onSubmit(addTypedEntry)
                    .accessibilityIdentifier("addListEntry")
                ForEach(suggestions) { suggestion in
                    Button {
                        add(suggestion.item(in: modelContext))
                    } label: {
                        Label(suggestion.name, systemImage: "plus")
                            .foregroundStyle(.primary)
                    }
                }
            }

            ForEach(AisleOrder.standard.sorted(list.orderedEntries, by: \.aisle), id: \.aisle) {
                group in
                Section(group.aisle.title) {
                    ForEach(group.elements) { entry in
                        row(for: entry)
                    }
                    .onMove { source, destination in
                        move(group.elements, from: source, to: destination)
                    }
                }
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Share", systemImage: "square.and.arrow.up") {
                    ListShare.present(ListSharing.payload(for: list))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename list", systemImage: "pencil") {
                        listName = list.name
                        isRenamingList = true
                    }
                    EditButton()
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("List options")
            }
        }
        // An inset rather than a bottom bar: the floating tab bar draws over a toolbar's bottom bar.
        .safeAreaInset(edge: .bottom) {
            Button {
                isPreparing = true
            } label: {
                Label("Shop this list", systemImage: "cart")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .accessibilityIdentifier("shopThisList")
        }
        .sheet(isPresented: $isPreparing) {
            ShopPrepSheet(list: list) { router.shop() }
        }
        .sheet(item: $editingEntry, onDismiss: { StoreUpkeep.prune(in: modelContext) }) { entry in
            if let item = entry.item {
                ItemForm(item: item, entry: entry)
            }
        }
        .alert("Rename list", isPresented: $isRenamingList) {
            TextField("Name", text: $listName)
            Button("Save", action: commitListRename)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var suggestions: [ItemSearchResult] {
        Array(ItemSearch.results(for: newEntryText, items: items, limit: 5))
    }

    private func row(for entry: ListEntry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            ListEntryRow(entry: entry)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(entry)
                save()
                StoreUpkeep.prune(in: modelContext)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation { entry.isSkipped.toggle() }
                save()
            } label: {
                Label(
                    entry.isSkipped ? "Need it" : "Not this time",
                    systemImage: entry.isSkipped ? "arrow.uturn.backward" : "minus.circle")
            }
            .tint(entry.isSkipped ? .accentColor : .gray)
        }
    }

    /// Return means "exactly what I typed"; a suggestion tap means "that item".
    private func addTypedEntry() {
        let text = newEntryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        add(ItemIdentity.item(named: text, in: modelContext))
    }

    private func add(_ item: GroceryItem) {
        withAnimation { _ = list.add(item) }
        save()
        newEntryText = ""
        isAddFieldFocused = true
    }

    /// Positions stay global, so a move only reorders within the aisle it happened in.
    private func move(_ group: [ListEntry], from source: IndexSet, to destination: Int) {
        var reordered = group
        reordered.move(fromOffsets: source, toOffset: destination)
        let slots = group.map(\.position).sorted()
        for (entry, position) in zip(reordered, slots) {
            entry.position = position
        }
        save()
    }

    private func commitListRename() {
        let trimmed = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        list.name = trimmed
        save()
    }

    private func save() {
        list.updatedAt = .now
        try? modelContext.save()
    }
}

private struct ListEntryRow: View {
    let entry: ListEntry
    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .foregroundStyle(entry.isSkipped ? .secondary : .primary)
                if let note = entry.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if entry.isSkipped {
                Text("not this time")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else if let summary = entry.item?.goodPriceSummary(preferring: storedUnit) {
                Text(summary)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
