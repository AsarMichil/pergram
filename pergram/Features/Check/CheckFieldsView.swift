import SwiftUI

struct CheckFieldsView: View {
    @Bindable var viewModel: CheckViewModel
    let selectedItemName: String?
    let baseline: NormalizedPrice?
    var onChooseItem: () -> Void
    var onSetGoodPrice: () -> Void
    var onClearItem: () -> Void
    var metrics: CheckMetrics = .roomy

    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue

    private var storedUnit: MeasureUnit { MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams }

    var body: some View {
        // The gap above the item row matches the one below it, so the row is evenly seated between
        // the card and the keypad. Both are capped, so spare height rises to the verdict panel.
        VStack(spacing: 0) {
            PriceExpressionCard(viewModel: viewModel, metrics: metrics)
            Spacer()
                .frame(minHeight: metrics.itemRowGap, maxHeight: metrics.itemRowGapMax)
            itemRow
        }
    }

    /// The item and the baseline it carries are one fact, so they are one row and one control —
    /// the actions that used to sit beside them as loose links live in its menu.
    private var itemRow: some View {
        Menu {
            Button("Choose item…", systemImage: "list.bullet", action: onChooseItem)
                .accessibilityIdentifier("chooseItem")
            if let goodPriceTitle {
                Button(goodPriceTitle, systemImage: "target", action: onSetGoodPrice)
            }
            if selectedItemName != nil {
                Button("Clear item", systemImage: "xmark", role: .destructive, action: onClearItem)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                Text(selectedItemName ?? "No item selected")
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let baseline {
                    Text(PriceDisplay.formatted(baseline, in: baselineUnit(for: baseline)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: CheckMetrics.smallerMinimumKeyHeight)
        }
        .buttonStyle(.glass)
        // Unlike the keypad there is no gap here to borrow — the card above and the keys below sit
        // `stackSpacing` away — so the row keeps a full-size target and only draws smaller inside it.
        .frame(minHeight: CheckMetrics.minimumKeyHeight)
        .contentShape(.rect)
        .accessibilityIdentifier("itemRow")
    }

    private var goodPriceTitle: String? {
        guard let price = viewModel.normalizedPrice else { return nil }
        let formatted = PriceDisplay.formatted(price, in: baselineUnit(for: price))
        return selectedItemName == nil
            ? "Save \(formatted) as a good price" : "Set good price to \(formatted)"
    }

    private func baselineUnit(for price: NormalizedPrice) -> MeasureUnit {
        PriceDisplay.displayUnit(for: price.dimension, preferred: storedUnit)
    }
}

#Preview("No item") {
    CheckFieldsView(
        viewModel: CheckViewModel(), selectedItemName: nil, baseline: nil,
        onChooseItem: {}, onSetGoodPrice: {}, onClearItem: {}
    )
    .padding()
}

#Preview("With baseline") {
    CheckFieldsView(
        viewModel: CheckViewModel(),
        selectedItemName: "Chicken thigh (boneless)",
        baseline: NormalizedPrice(dimension: .mass, canonical: 1.10),
        onChooseItem: {}, onSetGoodPrice: {}, onClearItem: {}
    )
    .padding()
}
