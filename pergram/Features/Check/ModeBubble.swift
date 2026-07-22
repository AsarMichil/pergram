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

    /// Each mode keeps a fixed side (Type left, Scan right); the active one is a labelled glass
    /// pill, the other collapses to a small glass dot that taps back to it.
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
            Button {
                withAnimation(reduceMotion ? nil : switchAnimation) { mode = target }
            } label: {
                Color.clear
                    .frame(width: 8, height: 8)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.small)
        }
    }
}

#Preview("Type") {
    ModeBubble(mode: .constant(.type))
}

#Preview("Scan") {
    ModeBubble(mode: .constant(.scan))
}
