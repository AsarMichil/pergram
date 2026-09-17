import SwiftUI

/// The parked price, and how the price being checked compares against it. Bookmarking is explicit
/// because a scan or a typed entry can be wrong — parking one is the user vouching for the reading,
/// so only vouched prices become a reference to compare against.
struct LastPriceChip: View {
    let price: NormalizedPrice
    var current: NormalizedPrice?
    var onDelete: () -> Void

    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayUnit: MeasureUnit {
        PriceDisplay.displayUnit(
            for: price.dimension, preferred: MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams)
    }

    private var difference: Double? {
        guard let current, current.dimension == price.dimension else { return nil }
        return PriceDisplay.value(current, in: displayUnit)
            - PriceDisplay.value(price, in: displayUnit)
    }

    private var popTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale(scale: 1.3).combined(with: .opacity)
            )
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "bookmark.fill")
            Text(PriceDisplay.formatted(price, in: displayUnit))
                .fontWeight(.semibold)
                .monospacedDigit()
            if let difference {
                Text("·").foregroundStyle(.tertiary)
                comparison(difference)
            }
            clearButton
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.leading, 11)
        .padding(.trailing, 2)
        .padding(.vertical, 3)
        .glassEffect(.regular, in: .capsule)
        .transition(popTransition)
    }

    @ViewBuilder
    private func comparison(_ difference: Double) -> some View {
        if abs(difference) < 0.005 {
            Text("same price")
        } else {
            Text(
                "\(abs(difference).formatted(PriceDisplay.currency)) \(difference < 0 ? "cheaper" : "pricier")"
            )
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle((difference < 0 ? Verdict.good : Verdict.bad).color)
            .contentTransition(reduceMotion ? .opacity : .numericText())
        }
    }

    private var clearButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
                .frame(width: 22, height: 22)
                .contentShape(.circle)
                .padding(6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tertiary)
        .accessibilityLabel("Clear parked price")
    }
}

#Preview("Cheaper") {
    LastPriceChip(
        price: NormalizedPrice(dimension: .mass, canonical: 1.23),
        current: NormalizedPrice(dimension: .mass, canonical: 1.05),
        onDelete: {}
    )
}

#Preview("Pricier") {
    LastPriceChip(
        price: NormalizedPrice(dimension: .mass, canonical: 1.05),
        current: NormalizedPrice(dimension: .mass, canonical: 1.23),
        onDelete: {}
    )
}

#Preview("No comparison yet") {
    LastPriceChip(price: NormalizedPrice(dimension: .mass, canonical: 1.05), onDelete: {})
}
