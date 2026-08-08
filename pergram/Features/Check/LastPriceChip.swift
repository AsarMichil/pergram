import SwiftUI

struct LastPriceChip: View {
    let pricePer100g: Double
    var onDelete: () -> Void

    @AppStorage("checkDisplayUnit") private var displayUnitRaw = MeasureUnit.per100Grams.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayUnit: MeasureUnit {
        MeasureUnit(rawValue: displayUnitRaw) ?? .per100Grams
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
            Image(systemName: "clock.arrow.circlepath")
            Text("last")
            Text(
                PriceDisplay.price(per100g: pricePer100g, in: displayUnit),
                format: .currency(code: "CAD")
            )
            .fontWeight(.semibold)
            .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
        .contentShape(.capsule)
        .onTapGesture(perform: onDelete)
        .transition(popTransition)
    }
}

#Preview {
    LastPriceChip(pricePer100g: 1.05, onDelete: {})
}
