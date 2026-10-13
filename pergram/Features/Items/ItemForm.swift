import SwiftData
import SwiftUI

/// Everything about one item in one place: its name and aisle, its good prices and — opened from a
/// list — what this list says about it. A sheet rather than menus because changing the aisle moves
/// the row, and a row that moves under a context menu's preview flashes.
struct ItemForm: View {
    let item: GroceryItem
    var entry: ListEntry?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @State private var name = ""
    @State private var aisle = Aisle.other
    @State private var note = ""
    @State private var isSettingGoodPrice = false

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("itemName")
                    Picker("Aisle", selection: $aisle) {
                        ForEach(Aisle.allCases, id: \.self) { aisle in
                            Text(aisle.title).tag(aisle)
                        }
                    }
                } footer: {
                    if entry != nil {
                        Text("Changes here apply on every list.")
                    }
                }

                if entry != nil {
                    Section("On this list") {
                        TextField("How many or which — 6, 2 lb, ripe ones", text: $note)
                            .accessibilityIdentifier("entryNote")
                    }
                }

                Section("Good price") {
                    ForEach(item.goodPrices, id: \.dimension) { price in
                        Text(format(price))
                            .monospacedDigit()
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    item.clearGoodPrice(for: price.dimension)
                                    item.updatedAt = .now
                                }
                            }
                    }
                    Button(item.hasGoodPrice ? "Set another" : "Set good price") {
                        isSettingGoodPrice = true
                    }
                }

                if let entry {
                    Section {
                        Button("Remove from list", role: .destructive) {
                            modelContext.delete(entry)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .sheet(isPresented: $isSettingGoodPrice) {
            AddEditItemSheet(item: item)
        }
        .onAppear {
            name = item.name
            aisle = item.aisle ?? .other
            note = entry?.note ?? ""
        }
    }

    private func save() {
        if trimmedName != item.name || aisle != item.aisle {
            item.name = trimmedName
            item.aisle = aisle
            item.userModified = true
            item.updatedAt = .now
        }
        if let entry {
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.note = trimmedNote.isEmpty ? nil : trimmedNote
        }
        try? modelContext.save()
        dismiss()
    }

    private func format(_ price: NormalizedPrice) -> String {
        PriceDisplay.formatted(
            price, in: PriceDisplay.displayUnit(for: price.dimension, preferred: storedUnit))
    }
}
