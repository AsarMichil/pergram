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
    @State private var linkingEntry: ListEntry?
    @State private var editingEntry: ListEntry?
    @State private var editText = ""
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
                        add(suggestion)
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

            if !(list.entries ?? []).isEmpty {
                Section {
                } footer: {
                    Text("Tap to link a good price. Swipe right to sit one out this time.")
                }
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: SharedListFile(payload: ListSharing.payload(for: list)),
                    preview: SharePreview(list.name, image: Image(systemName: "checklist"))
                )
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
        .sheet(item: $linkingEntry) { entry in
            ItemPickerSheet(
                selectedItemID: Binding(
                    get: { entry.item?.persistentModelID },
                    set: { id in
                        entry.item = id.flatMap { modelContext.registeredModel(for: $0) }
                        if let aisle = entry.item?.aisle { entry.aisle = aisle }
                        save()
                    }
                )
            )
        }
        .alert(
            "Rename item",
            isPresented: Binding(
                get: { editingEntry != nil }, set: { if !$0 { editingEntry = nil } })
        ) {
            TextField("Name", text: $editText)
            Button("Save", action: commitEntryRename)
            Button("Cancel", role: .cancel) {}
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
        ListEntryRow(entry: entry)
            .contentShape(.rect)
            .onTapGesture { linkingEntry = entry }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    modelContext.delete(entry)
                    save()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    editText = entry.text
                    editingEntry = entry
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.indigo)
            }
            .swipeActions(edge: .leading) {
                Button {
                    entry.isSkipped.toggle()
                    save()
                } label: {
                    Label(
                        entry.isSkipped ? "Need it" : "Not this time",
                        systemImage: entry.isSkipped
                            ? "arrow.uturn.backward" : "minus.circle")
                }
                .tint(entry.isSkipped ? .accentColor : .gray)
            }
            .contextMenu {
                Menu("Move to aisle", systemImage: "arrow.up.arrow.down") {
                    ForEach(Aisle.allCases, id: \.self) { aisle in
                        Button(aisle.title) {
                            entry.aisle = aisle
                            save()
                        }
                    }
                }
            }
    }

    private func addTypedEntry() {
        let text = newEntryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let item = CatalogLibrary.exactItem(named: text, among: items, in: modelContext)
        append(text, item: item)
    }

    private func add(_ suggestion: ItemSearchResult) {
        switch suggestion {
        case .item(let item): append(item.name, item: item)
        case .entry(let entry):
            append(entry.name, item: CatalogLibrary.item(for: entry, in: modelContext))
        }
    }

    /// An exact name links itself, so "bananas" carries its good price without a trip to the picker,
    /// and anything unlinked still lands in the aisle its words suggest.
    private func append(_ text: String, item: GroceryItem?) {
        let aisle = item?.aisle ?? CatalogLibrary.bundled.guessAisle(for: text)
        let entry = list.append(text, item: item, aisle: aisle)
        modelContext.insert(entry)
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

    private func commitEntryRename() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editingEntry, !trimmed.isEmpty {
            editingEntry.text = trimmed
            save()
        }
        editingEntry = nil
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

    var body: some View {
        HStack {
            Text(entry.text)
                .foregroundStyle(entry.isSkipped ? .secondary : .primary)
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

    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
}
