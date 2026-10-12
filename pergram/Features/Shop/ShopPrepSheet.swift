import SwiftData
import SwiftUI

/// The step between a list and a trip: say what you are sitting out this time. The choices are
/// written to the list's flags, not the trip, so they carry to the next shop and travel when the list
/// is shared. Held locally until Start, so Cancel leaves the list as it was.
struct ShopPrepSheet: View {
    let list: GroceryList
    var onStart: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var skipped: Set<UUID> = []

    private var groups: [(aisle: Aisle, elements: [ListEntry])] {
        AisleOrder.standard.sorted(list.orderedEntries, by: \.aisle)
    }

    private var neededCount: Int { (list.entries?.count ?? 0) - skipped.count }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.aisle) { group in
                    Section(group.aisle.title) {
                        ForEach(group.elements) { entry in
                            Toggle(entry.text, isOn: binding(for: entry))
                        }
                    }
                }
            }
            .overlay {
                if list.orderedEntries.isEmpty {
                    ContentUnavailableView(
                        "Nothing on this list", systemImage: "checklist",
                        description: Text("You can still shop it and add prices as you go."))
                }
            }
            .navigationTitle(list.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: start)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("startShopping")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(neededCount == 1 ? "1 item to get" : "\(neededCount) items to get")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            skipped = Set(list.orderedEntries.filter(\.isSkipped).map(\.id))
        }
    }

    private func binding(for entry: ListEntry) -> Binding<Bool> {
        Binding(
            get: { !skipped.contains(entry.id) },
            set: { needed in
                if needed { skipped.remove(entry.id) } else { skipped.insert(entry.id) }
            }
        )
    }

    private func start() {
        for entry in list.orderedEntries {
            entry.isSkipped = skipped.contains(entry.id)
        }
        Shopping.startTrip(shopping: list, in: modelContext)
        dismiss()
        onStart()
    }
}
