import SwiftUI
import TipKit

struct UnitCycleTip: Tip {
    @Parameter static var hasPricedSomething: Bool = false

    var title: Text { Text("Tap the unit to switch it") }

    var rules: [Rule] {
        #Rule(Self.$hasPricedSomething) { $0 }
    }

    var options: [any TipOption] {
        MaxDisplayCount(1)
    }
}

/// Inline and chip-sized, in the slot the parked price uses. A popover there arrived mid-entry and
/// took the next keystroke to dismiss it.
struct ChipTipStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "hand.tap")
            configuration.title
            Button {
                configuration.tip.invalidate(reason: .tipClosed)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .frame(width: 22, height: 22)
                    .contentShape(.circle)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .accessibilityLabel("Dismiss tip")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.leading, 11)
        .padding(.trailing, 2)
        .padding(.vertical, 3)
        .glassEffect(.regular, in: .capsule)
    }
}
