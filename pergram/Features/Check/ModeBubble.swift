import SwiftUI

struct ModeBubble: View {
    @Binding var mode: CheckInputMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var switchAnimation: Animation { .spring(response: 0.4, dampingFraction: 0.82) }

    var body: some View {
        HStack(spacing: 8) {
            element(for: .type)
            element(for: .scan)
        }
        .animation(reduceMotion ? nil : switchAnimation, value: mode)
        .sensoryFeedback(.selection, trigger: mode)
    }

    @ViewBuilder
    private func element(for target: CheckInputMode) -> some View {
        if mode == target {
            Button {
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: target.symbolName)
                    Text(target.title)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 6)
                .frame(height: 20)
            }
            .buttonStyle(.glass)
            .allowsHitTesting(false)
        } else {
            // The 44pt minimum governs the touch target, not the artwork, so the hit region is
            // widened past the glass rather than inflating it — the collapsed glyph is the design.
            Button {
                withAnimation(reduceMotion ? nil : switchAnimation) { mode = target }
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
}

#Preview("Type") {
    ModeBubble(mode: .constant(.type))
}

#Preview("Scan") {
    ModeBubble(mode: .constant(.scan))
}
