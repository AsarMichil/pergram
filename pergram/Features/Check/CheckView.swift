import SwiftData
import SwiftUI

nonisolated enum CheckInputMode: CaseIterable, Hashable, Sendable {
    case type
    case scan

    var toggled: CheckInputMode { self == .type ? .scan : .type }
    var title: String { self == .type ? "Type" : "Scan" }
    var symbolName: String { self == .type ? "keyboard" : "camera.viewfinder" }
}

struct CheckView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CheckViewModel()
    @State private var mode: CheckInputMode = .type
    @State private var isShowingItemPicker = false
    @State private var isShowingSaveSheet = false

    // iOS 26 lays a TabView tab's content edge-to-edge: neither the Dynamic Island / status bar
    // nor the floating tab bar reduces the safe area for non-scrolling content, and no API exposes
    // their heights, so this fixed keypad screen clears both bars with manual insets.
    private static let islandClearance: CGFloat = 60
    private static let tabBarHeight: CGFloat = 49
    private static let bottomBreathingRoom: CGFloat = 15
    private static let tabBarClearance = tabBarHeight + bottomBreathingRoom

    var body: some View {
        VStack(spacing: 12) {
            ModeBubble(mode: $mode)

            Spacer(minLength: 0)

            VerdictPanelView(
                pricePer100g: viewModel.pricePer100g,
                baselinePer100g: viewModel.selectedItem?.goodPricePer100g,
                settledVerdict: viewModel.settledVerdict,
                isSettled: viewModel.isSettled,
                hasEnoughInput: viewModel.hasEnoughInput,
                settleTick: viewModel.settleTick,
                onSaveAsGoodPrice: {
                    if viewModel.selectedItem == nil {
                        isShowingSaveSheet = true
                    } else {
                        viewModel.updateSelectedGoodPrice()
                    }
                }
            )

            inputZone
                .padding(.horizontal)
        }
        .padding(.top, Self.islandClearance)
        .padding(.bottom, Self.tabBarClearance)
        .contentShape(Rectangle())
        .simultaneousGesture(modeSwipe)
        .onAppear { viewModel.attach(modelContext: modelContext) }
        .sheet(isPresented: $isShowingItemPicker) {
            ItemPickerSheet(selectedItem: $viewModel.selectedItem)
        }
        .sheet(isPresented: $isShowingSaveSheet) {
            if let pricePer100g = viewModel.pricePer100g {
                SetGoodPriceSheet(pricePer100g: pricePer100g) { name in
                    viewModel.saveAsGoodPrice(named: name)
                }
            }
        }
    }

    @ViewBuilder
    private var inputZone: some View {
        switch mode {
        case .type:
            VStack(spacing: 12) {
                CheckFieldsView(viewModel: viewModel, isShowingItemPicker: $isShowingItemPicker)
                KeypadView(viewModel: viewModel)
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
        case .scan:
            ScanModeView()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private var modeSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) * 1.5,
                    abs(horizontal) > 60
                else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    mode = horizontal < 0 ? .scan : .type
                }
            }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: GroceryItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(
        GroceryItem(
            id: "chicken-thigh-boneless",
            name: "Chicken thigh (boneless)",
            aliases: ["thighs"],
            category: "meat",
            goodPricePer100g: 1.10
        )
    )
    return CheckView()
        .modelContainer(container)
}
