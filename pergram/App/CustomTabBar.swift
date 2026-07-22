import SwiftUI

enum AppTab: CaseIterable, Hashable {
    case check
    case items
    case settings

    var title: String {
        switch self {
        case .check: return "Check"
        case .items: return "Items"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .check: return "checkmark.circle"
        case .items: return "cart"
        case .settings: return "gearshape"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab
    let isExpanded: Bool
    let onActivity: () -> Void

    @Namespace private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isExpanded {
                expandedBar
            } else {
                minimizedBar
            }
        }
        .padding(.bottom, 4)
    }

    private var expandedBar: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    onActivity()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8))
                    {
                        selection = tab
                    }
                } label: {
                    tabLabel(tab)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .transition(.blurReplace)
    }

    private var minimizedBar: some View {
        Button {
            onActivity()
        } label: {
            Image(systemName: selection.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(.vertical, 9)
                .padding(.horizontal, 22)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .transition(.blurReplace)
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return VStack(spacing: 2) {
            Image(systemName: tab.symbol)
                .font(.system(size: 18))
            Text(tab.title)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        .frame(width: 76)
        .padding(.vertical, 7)
        .background {
            if isSelected {
                Capsule()
                    .fill(.tint.opacity(0.14))
                    .matchedGeometryEffect(id: "selection", in: highlight)
            }
        }
        .contentShape(.capsule)
    }
}

#Preview("Expanded") {
    CustomTabBar(selection: .constant(.check), isExpanded: true, onActivity: {})
}

#Preview("Minimized") {
    CustomTabBar(selection: .constant(.check), isExpanded: false, onActivity: {})
}
