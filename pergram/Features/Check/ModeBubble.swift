import SwiftUI

struct ModeBubble: View {
    @Binding var mode: CheckInputMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass

    private var switchAnimation: Animation { .spring(response: 0.4, dampingFraction: 0.82) }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                element(for: .type)
                element(for: .scan)
            }
        }
        .animation(reduceMotion ? nil : switchAnimation, value: mode)
        .sensoryFeedback(.selection, trigger: mode)
    }

    /// Each mode keeps a fixed side (Type left, Scan right); the active one is a labelled pill, the
    /// other collapses to a bare dot that taps back to it.
    @ViewBuilder
    private func element(for target: CheckInputMode) -> some View {
        let isActive = mode == target
        Button {
            guard !isActive else { return }
            withAnimation(reduceMotion ? nil : switchAnimation) { mode = target }
        } label: {
            Group {
                if isActive {
                    HStack(spacing: 6) {
                        Image(systemName: target.symbolName)
                        Text(target.title)
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 14)
                } else {
                    Color.clear
                        .frame(width: 34, height: 34)
                }
            }
            .font(.subheadline.weight(.semibold))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID(target, in: glass)
    }
}

#Preview("Type") {
    ModeBubble(mode: .constant(.type))
}

#Preview("Scan") {
    ModeBubble(mode: .constant(.scan))
}
