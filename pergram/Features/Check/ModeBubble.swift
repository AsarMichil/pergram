import SwiftUI

struct ModeBubble: View {
    @Binding var mode: CheckInputMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsLabel = false
    @State private var collapseTask: Task<Void, Never>?

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                mode = mode.toggled
            }
        } label: {
            HStack(spacing: showsLabel ? 6 : 0) {
                Image(systemName: mode.symbolName)
                    .contentTransition(.symbolEffect(.replace))
                if showsLabel {
                    Text(mode.title)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 7)
            .padding(.horizontal, showsLabel ? 14 : 9)
        }
        .buttonStyle(.glass)
        .sensoryFeedback(.selection, trigger: mode)
        .onAppear { revealLabel() }
        .onChange(of: mode) { revealLabel() }
    }

    /// Rests as a bare icon and expands to the word only on a mode change, then settles back,
    /// so the switcher stays out of the verdict's way. Reduce Motion keeps the word pinned.
    private func revealLabel() {
        collapseTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showsLabel = true }
        guard !reduceMotion else { return }
        collapseTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showsLabel = false }
        }
    }
}

#Preview {
    ModeBubble(mode: .constant(.type))
}
