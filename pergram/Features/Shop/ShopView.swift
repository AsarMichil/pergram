import SwiftData
import SwiftUI

/// The cart and the list being shopped. Replaces everything below the mode row: a list needs scroll
/// room the fixed Check column cannot give.
struct ShopView: View {
    let trip: Trip?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryList.name) private var lists: [GroceryList]
    @State private var editingEntry: CartEntry?
    @State private var matchingEntry: CartEntry?
    @State private var isShowingSummary = false

    var body: some View {
        if let trip {
            tripContent(trip)
        } else {
            noTrip
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
                Section(list.name) {
                    ForEach(list.orderedEntries) { entry in
                        ShopListRow(entry: entry, isCrossed: trip.isCrossed(entry)) {
                            Shopping.setCrossed(!trip.isCrossed(entry), for: entry, in: trip)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                entry.isSkipped.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(
                                    entry.isSkipped ? "Need it" : "Not this time",
                                    systemImage: entry.isSkipped
                                        ? "arrow.uturn.backward" : "minus.circle")
                            }
                            .tint(entry.isSkipped ? .accentColor : .gray)
                        }
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
                Text(tally.count == 1 ? "1 item" : "\(tally.count) items")
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

    private func listMenu(title: String) -> some View {
        Menu(title, systemImage: "checklist") {
            ForEach(lists) { list in
                Button(list.name) { Shopping.startTrip(shopping: list, in: modelContext) }
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

private struct ShopListRow: View {
    let entry: ListEntry
    let isCrossed: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(isCrossed ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
                Text(entry.text)
                    .strikethrough(isCrossed)
                    .foregroundStyle(isCrossed || isSittingOut ? .secondary : .primary)
                Spacer(minLength: 8)
                if isSittingOut {
                    Text("not this time")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isCrossed ? "Got it" : isSittingOut ? "Not this time" : "")
    }

    /// Buying a flagged entry anyway crosses it for this trip; the flag stays for the next one.
    private var isSittingOut: Bool { entry.isSkipped && !isCrossed }

    private var symbol: String {
        if isCrossed { return "checkmark.circle.fill" }
        return isSittingOut ? "minus.circle" : "circle"
    }
}
