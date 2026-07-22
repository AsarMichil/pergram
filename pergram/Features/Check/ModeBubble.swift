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

    /// Each mode keeps a fixed side (Type left, Scan right); the active one is a labelled glass
    /// pill, the other collapses to a small interactive glass dot that taps back to it.
    @ViewBuilder
    private func element(for target: CheckInputMode) -> some View {
        let isActive = mode == target
        Group {
            if isActive {
                HStack(spacing: 6) {
                    Image(systemName: target.symbolName)
                    Text(target.title)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
            } else {
                Color.clear
                    .frame(width: 26, height: 26)
            }
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID(target, in: glass)
        .contentShape(.capsule)
        .onTapGesture {
            guard !isActive else { return }
            withAnimation(reduceMotion ? nil : switchAnimation) { mode = target }
        }
    }
}

#Preview("Type") {
    ModeBubble(mode: .constant(.type))
}

#Preview("Scan") {
    ModeBubble(mode: .constant(.scan))
}
