import SwiftData
import SwiftUI

/// The cart and the list being shopped. Replaces everything below the mode row: a list needs scroll
/// room the fixed Check column cannot give.
struct ShopView: View {
    let trip: Trip?
    /// Called when the shopper taps a list entry to price it: Check selects it and goes back to Type
    /// or Scan.
    var onPrice: (ListEntry) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryList.name) private var lists: [GroceryList]
    @State private var editingEntry: CartEntry?
    @State private var matchingEntry: CartEntry?
    @State private var isShowingSummary = false
    @State private var preparingList: GroceryList?

    var body: some View {
        Group {
            if let trip {
                tripContent(trip)
            } else {
                noTrip
            }
        }
        .sheet(item: $preparingList) { list in
            ShopPrepSheet(list: list) {}
        }
    }

    private var noTrip: some View {
        ContentUnavailableView {
            Label("No trip running", systemImage: "cart")
        } description: {
            Text("Add a price to the cart from Type or Scan, or shop one of your lists.")
        } actions: {
            Button("Start trip") { Shopping.startTrip(in: modelContext) }
                .buttonStyle(.glassProminent)
            if !lists.isEmpty {
                listMenu(title: "Shop a list")
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func tripContent(_ trip: Trip) -> some View {
        let tally = trip.tally
        return List {
            Section {
                header(trip, tally: tally)
            }
            .listRowBackground(Color.clear)

            Section("Cart") {
                if trip.orderedEntries.isEmpty {
                    Text("Nothing yet. Add a price from Type or Scan.")
                        .foregroundStyle(.secondary)
                }
                ForEach(trip.orderedEntries) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        CartRow(entry: entry, label: trip.label(for: entry))
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    // Leading only: Shop is the leftmost mode, so a swipe left anywhere on
                    // this page belongs to the mode swipe, back to Type.
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Shopping.remove(entry, in: modelContext)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        if trip.list != nil, entry.listEntryID == nil {
                            Button {
                                matchingEntry = entry
                            } label: {
                                Label("Match to list", systemImage: "checklist")
                            }
                            .tint(.indigo)
                        }
                    }
                }
            }

            if let list = trip.list {
                // In store order, so the list reads in the order the aisles are walked. Entries sat
                // out this time fold away at the end, still there if the shopper changes their mind.
                ForEach(
                    AisleOrder.standard.sorted(needed(in: list, trip: trip), by: \.aisle),
                    id: \.aisle
                ) { group in
                    Section(group.aisle.title) {
                        ForEach(group.elements) { entry in
                            listRow(entry, in: trip)
                        }
                    }
                }
                let sittingOut = list.orderedEntries.filter { $0.isSkipped && !trip.isCrossed($0) }
                if !sittingOut.isEmpty {
                    Section {
                        DisclosureGroup("Not this time (\(sittingOut.count))") {
                            ForEach(sittingOut) { entry in
                                listRow(entry, in: trip)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Finish trip") { isShowingSummary = true }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("finishTrip")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sensoryFeedback(.selection, trigger: trip.crossedEntryIDs)
        .sheet(item: $editingEntry) { entry in
            QuantitySheet(entry: entry, label: trip.label(for: entry))
        }
        .sheet(item: $matchingEntry) { entry in
            MatchToListSheet(entry: entry, trip: trip)
        }
        .sheet(isPresented: $isShowingSummary) {
            TripSummarySheet(trip: trip)
        }
    }

    private func header(_ trip: Trip, tally: CartTally) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PriceDisplay.money(tally.total))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: tally.total)
                    .accessibilityIdentifier("cartTotal")
                Text(subtitle(trip, tally: tally))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                if !lists.isEmpty {
                    listMenu(title: trip.list == nil ? "Shop a list" : "Switch list")
                }
                Button("Finish trip", systemImage: "flag.checkered") { isShowingSummary = true }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Trip options")
        }
    }

    /// Crossed entries stay in their aisle even when flagged: buying one anyway is still buying it.
    private func needed(in list: GroceryList, trip: Trip) -> [ListEntry] {
        list.orderedEntries.filter { !$0.isSkipped || trip.isCrossed($0) }
    }

    private func listRow(_ entry: ListEntry, in trip: Trip) -> some View {
        ShopListRow(
            entry: entry,
            isCrossed: trip.isCrossed(entry),
            onToggle: { Shopping.setCrossed(!trip.isCrossed(entry), for: entry, in: trip) },
            onPrice: { onPrice(entry) }
        )
        .contextMenu {
            Button(
                entry.isSkipped ? "Need it this time" : "Not this time",
                systemImage: entry.isSkipped ? "arrow.uturn.backward" : "minus.circle"
            ) {
                entry.isSkipped.toggle()
                try? modelContext.save()
            }
            Menu("Move to aisle", systemImage: "arrow.up.arrow.down") {
                ForEach(Aisle.allCases, id: \.self) { aisle in
                    Button(aisle.title) {
                        entry.aisle = aisle
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    private func subtitle(_ trip: Trip, tally: CartTally) -> String {
        let count = tally.count == 1 ? "1 item" : "\(tally.count) items"
        guard let list = trip.list else { return count }
        return "\(count) · \(list.name)"
    }

    private func listMenu(title: String) -> some View {
        Menu(title, systemImage: "checklist") {
            ForEach(lists) { list in
                Button(list.name) { preparingList = list }
            }
        }
    }

}

private struct CartRow: View {
    let entry: CartEntry
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .lineLimit(1)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(PriceDisplay.money(entry.line.total))
                .monospacedDigit()
            if let verdict = entry.verdict {
                Image(systemName: verdict.symbolName)
                    .foregroundStyle(verdict.color)
                    .accessibilityLabel(verdict.word)
            }
        }
    }

    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue

    /// The unit price is what the verdict judged; the quantity only appears once there is more than
    /// one, since `× 1` would just repeat the line total.
    private var detail: String {
        var parts: [String] = []
        if entry.quantity != 1 {
            parts.append(
                "\(PriceDisplay.money(entry.price)) × \(QuantitySheet.format(entry.quantity))")
        }
        if let unitPrice = entry.unitPrice {
            let preferred = MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams
            let unit = PriceDisplay.displayUnit(for: unitPrice.dimension, preferred: preferred)
            parts.append(PriceDisplay.formatted(unitPrice, in: unit))
        }
        return parts.joined(separator: " · ")
    }
}

/// Two targets: the circle crosses an entry off by hand, the rest of the row goes to price it, since
/// pricing is the more useful thing to do with an item you are standing in front of.
private struct ShopListRow: View {
    let entry: ListEntry
    let isCrossed: Bool
    var onToggle: () -> Void
    var onPrice: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isCrossed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCrossed ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCrossed ? "Uncross \(entry.text)" : "Cross off \(entry.text)")

            Button(action: onPrice) {
                HStack(spacing: 8) {
                    Text(entry.text)
                        .strikethrough(isCrossed)
                        .foregroundStyle(isCrossed ? .secondary : .primary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Price \(entry.text)")
            .accessibilityValue(isCrossed ? "Got it" : "")
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 16))
    }
}
