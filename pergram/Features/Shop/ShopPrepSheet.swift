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

    private var totalCount: Int { list.entries?.count ?? 0 }
    private var neededCount: Int { totalCount - skipped.count }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.aisle) { group in
                    Section(group.aisle.title) {
                        ForEach(group.elements) { entry in
                            PrepRow(entry: entry, isNeeded: !skipped.contains(entry.id)) {
                                toggle(entry)
                            }
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
            .navigationSubtitle(totalCount > 0 ? "Uncheck what to skip" : "")
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
            .toolbar {
                if totalCount > 0 {
                    ToolbarItem(placement: .bottomBar) {
                        Text("\(neededCount) of \(totalCount) to get")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .fixedSize()
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) {
                        if skipped.isEmpty {
                            Button("Skip All") { withAnimation { skipAll() } }
                        } else {
                            Button("Get All") { withAnimation { skipped.removeAll() } }
                        }
                    }
                }
            }
        }
        .onAppear {
            skipped = Set(list.orderedEntries.filter(\.isSkipped).map(\.id))
        }
    }

    private func toggle(_ entry: ListEntry) {
        if skipped.contains(entry.id) { skipped.remove(entry.id) } else { skipped.insert(entry.id) }
    }

    private func skipAll() {
        skipped = Set(list.orderedEntries.map(\.id))
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

private struct PrepRow: View {
    let entry: ListEntry
    let isNeeded: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isNeeded ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isNeeded ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .foregroundStyle(isNeeded ? .primary : .secondary)
                    if let note = entry.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.name)
        .accessibilityValue(isNeeded ? "Getting" : "Skipping this time")
        .accessibilityAddTraits(isNeeded ? .isSelected : [])
    }
}
