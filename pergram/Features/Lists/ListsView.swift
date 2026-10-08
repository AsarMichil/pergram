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
    @State private var newEntryText = ""
    @State private var linkingEntry: ListEntry?
    @State private var editingEntry: ListEntry?
    @State private var editText = ""
    @State private var isRenamingList = false
    @State private var listName = ""
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        List {
            Section {
                TextField("Add an item", text: $newEntryText)
                    .focused($isAddFieldFocused)
                    .submitLabel(.next)
                    .onSubmit(addEntry)
                    .accessibilityIdentifier("addListEntry")
            }

            Section {
                ForEach(list.orderedEntries) { entry in
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
                }
                .onMove(perform: move)
            } footer: {
                if !(list.entries ?? []).isEmpty {
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
                Shopping.startTrip(shopping: list, in: modelContext)
                router.shop()
            } label: {
                Label("Shop this list", systemImage: "cart")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .accessibilityIdentifier("shopThisList")
        }
        .sheet(item: $linkingEntry) { entry in
            ItemPickerSheet(
                selectedItemID: Binding(
                    get: { entry.item?.persistentModelID },
                    set: { id in
                        entry.item = id.flatMap { modelContext.model(for: $0) as? GroceryItem }
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

    private func addEntry() {
        let trimmed = newEntryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = list.append(trimmed, item: catalogMatch(for: trimmed))
        modelContext.insert(entry)
        save()
        newEntryText = ""
        isAddFieldFocused = true
    }

    /// An exact name or alias match links itself, so "bananas" carries its good price without a trip
    /// to the picker. Anything looser is left for the shopper to link.
    private func catalogMatch(for text: String) -> GroceryItem? {
        let query = text.lowercased()
        let items = (try? modelContext.fetch(FetchDescriptor<GroceryItem>())) ?? []
        return items.first { item in
            item.name.lowercased() == query || item.aliases.contains { $0.lowercased() == query }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var entries = list.orderedEntries
        entries.move(fromOffsets: source, toOffset: destination)
        for (position, entry) in entries.enumerated() {
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
            } else if let item = entry.item {
                Text(goodPrice(item))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func goodPrice(_ item: GroceryItem) -> String {
        let price = NormalizedPrice(dimension: item.dimension, canonical: item.goodPriceCanonical)
        return PriceDisplay.formatted(price, in: MeasureUnit.canonicalUnit(for: item.dimension))
    }
}
