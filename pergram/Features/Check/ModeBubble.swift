import SwiftUI

struct ModeBubble: View {
    @Binding var mode: CheckInputMode
    /// The running trip's total, or `nil` with no trip. It rides on the Shop chip so the cart is
    /// visible from Type and Scan without a row of its own.
    var cartTotal: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass

    private var switchAnimation: Animation { .spring(response: 0.35, dampingFraction: 0.8) }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(CheckInputMode.allCases, id: \.self, content: element)
            }
        }
        .animation(reduceMotion ? nil : switchAnimation, value: mode)
        .animation(reduceMotion ? nil : switchAnimation, value: cartTotal)
        .sensoryFeedback(.selection, trigger: mode)
    }

    private func totalText(for target: CheckInputMode) -> String? {
        guard target == .shop, let cartTotal else { return nil }
        return PriceDisplay.money(cartTotal)
    }

    /// One view per mode whatever its state, so a switch morphs one shape rather than fading a
    /// capsule out in one place and a circle in at another. Every element takes the same 8pt either
    /// side, which evens the visible gaps and keeps a 44pt target around the 28pt circles.
    private func element(for target: CheckInputMode) -> some View {
        let isSelected = mode == target
        let total = totalText(for: target)
        let isCircle = !isSelected && total == nil
        return Button {
            mode = target
        } label: {
            HStack(spacing: 6) {
                Image(systemName: target.symbolName)
                // With a trip running the total names the Shop mode, so the word would only crowd it.
                if isSelected && total == nil {
                    Text(target.title)
                }
                if let total {
                    Text(total)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .font(isSelected ? .subheadline.weight(.semibold) : .footnote.weight(.semibold))
            .padding(.horizontal, isCircle ? 0 : isSelected ? 14 : 10)
            .frame(width: isCircle ? 28 : nil, height: isSelected ? 34 : 28)
            // Words leaving a shrinking capsule are wiped by its edge rather than fading out over
            // the element beside it.
            .clipShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectID(target, in: glass)
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isSelected)
        .accessibilityLabel(accessibilityLabel(for: target, total: total))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityLabel(for target: CheckInputMode, total: String?) -> String {
        let name = mode == target ? target.title : "Switch to \(target.title)"
        guard let total else { return name }
        return "\(name), cart \(total)"
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
