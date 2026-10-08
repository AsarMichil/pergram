import SwiftUI

struct ModeBubble: View {
    @Binding var mode: CheckInputMode
    /// The running trip's total, or `nil` with no trip. It rides on the Shop chip so the cart is
    /// visible from Type and Scan without a row of its own.
    var cartTotal: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var switchAnimation: Animation { .spring(response: 0.4, dampingFraction: 0.82) }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CheckInputMode.allCases, id: \.self, content: element)
        }
        .animation(reduceMotion ? nil : switchAnimation, value: mode)
        .animation(reduceMotion ? nil : switchAnimation, value: cartTotal)
        .sensoryFeedback(.selection, trigger: mode)
    }

    private func totalText(for target: CheckInputMode) -> String? {
        guard target == .shop, let cartTotal else { return nil }
        return PriceDisplay.money(cartTotal)
    }

    @ViewBuilder
    private func element(for target: CheckInputMode) -> some View {
        if mode == target {
            Button {
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: target.symbolName)
                    Text(target.title)
                    if let total = totalText(for: target) {
                        Text(total)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 6)
                .frame(height: 20)
            }
            .buttonStyle(.glass)
            .allowsHitTesting(false)
        } else if let total = totalText(for: target) {
            Button {
                select(target)
            } label: {
                HStack(spacing: 4) {
                    Text(total)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Image(systemName: target.symbolName)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .glassEffect(.regular.interactive(), in: .capsule)
                .frame(height: 44)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch to \(target.title), cart \(total)")
        } else {
            // The 44pt minimum governs the touch target, not the artwork, so the hit region is
            // widened past the glass rather than inflating it — the collapsed glyph is the design.
            Button {
                select(target)
            } label: {
                Image(systemName: target.symbolName)
                    .font(.caption.weight(.semibold))
                    .frame(width: 26, height: 26)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch to \(target.title)")
        }
    }

    private func select(_ target: CheckInputMode) {
        withAnimation(reduceMotion ? nil : switchAnimation) { mode = target }
    }
}

#Preview("Type") {
    ModeBubble(mode: .constant(.type))
}

#Preview("Type, trip running") {
    ModeBubble(mode: .constant(.type), cartTotal: 42.18)
}

#Preview("Shop") {
    ModeBubble(mode: .constant(.shop), cartTotal: 42.18)
}
