import SwiftData
import SwiftUI

/// Quantity lives here and not on Check: deciding *how many* happens once, at the cart, while the
/// aisle screen stays about one price.
struct QuantitySheet: View {
    let entry: CartEntry
    let label: String
    /// Asks the presenter to remove the entry once the sheet is gone: deleting it here would leave
    /// the dismissing sheet reading a deleted model.
    var onRemove: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFieldFocused: Bool

    private var quantity: Double? {
        Double(text.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    stepButton("minus", delta: -1)
                    TextField("Quantity", text: $text)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .focused($isFieldFocused)
                        .accessibilityIdentifier("quantityField")
                    stepButton("plus", delta: 1)
                }
                Text(totalLine)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("Remove from cart", role: .destructive) {
                    onRemove()
                    dismiss()
                }
                .accessibilityIdentifier("removeFromCart")
            }
            .padding()
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .disabled(quantity == nil)
                }
            }
        }
        .presentationDetents([.height(280)])
        .onAppear { text = Self.format(entry.quantity) }
    }

    private var totalLine: String {
        let each = PriceDisplay.money(entry.price)
        guard let quantity else { return each }
        return "\(each) × \(Self.format(quantity)) = \(PriceDisplay.money(entry.price * quantity))"
    }

    private func stepButton(_ symbol: String, delta: Double) -> some View {
        Button {
            let stepped = (quantity ?? entry.quantity) + delta
            guard stepped > 0 else { return }
            text = Self.format(stepped)
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(delta > 0 ? "More" : "Fewer")
    }

    private func save() {
        guard let quantity else { return }
        Shopping.setQuantity(quantity, for: entry, in: modelContext)
        dismiss()
    }

    static func format(_ quantity: Double) -> String {
        quantity.formatted(.number.precision(.fractionLength(0...3)))
    }
}

/// The end of a trip is a verdict, not a receipt: what you spent, how it rated, and the bad buys
/// and forgotten items named while you can still do something about them.
struct TripSummarySheet: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }
    private var badBuys: [CartEntry] { trip.orderedEntries.filter { $0.verdict == .bad } }

    private var stillNeeded: [ListEntry] {
        (trip.list?.orderedEntries ?? []).filter { !$0.isSkipped && !trip.isCrossed($0) }
    }

    var body: some View {
        let tally = trip.tally
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PriceDisplay.money(tally.total))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(summaryLine(tally))
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("What you checked, before tax and deposits.")
                }

                if !badBuys.isEmpty {
                    Section("Bad buys") {
                        ForEach(badBuys) { entry in
                            Label {
                                Text(entry.label)
                            } icon: {
                                Image(systemName: Verdict.bad.symbolName)
                                    .foregroundStyle(Verdict.bad.color)
                            }
                        }
                    }
                }

                let suggestions = Shopping.goodPriceSuggestions(for: trip)
                if !suggestions.isEmpty {
                    Section {
                        ForEach(suggestions) { suggestion in
                            LabeledContent(suggestion.item.name) {
                                Button("Use \(format(suggestion.price))") {
                                    withAnimation {
                                        Shopping.useAsGoodPrice(suggestion, in: modelContext)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .monospacedDigit()
                            }
                        }
                    } header: {
                        Text("No good price yet")
                    } footer: {
                        Text("What you paid is a fair place to start. You can change it in Items.")
                    }
                }

                if !stillNeeded.isEmpty {
                    Section("Still on your list") {
                        ForEach(stillNeeded) { entry in
                            Label(entry.name, systemImage: "circle")
                        }
                    }
                }
            }
            .navigationTitle("Finish trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep shopping") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        Shopping.finish(trip, in: modelContext)
                        dismiss()
                    }
                    .accessibilityIdentifier("confirmFinishTrip")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func format(_ price: NormalizedPrice) -> String {
        PriceDisplay.formatted(
            price, in: PriceDisplay.displayUnit(for: price.dimension, preferred: storedUnit))
    }

    private func summaryLine(_ tally: CartTally) -> String {
        var parts = [tally.count == 1 ? "1 item" : "\(tally.count) items"]
        if tally.good > 0 { parts.append("\(tally.good) good") }
        if tally.meh > 0 { parts.append("\(tally.meh) meh") }
        if tally.bad > 0 { parts.append("\(tally.bad) bad") }
        return parts.joined(separator: " · ")
    }
}
