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

    var body: some View {
        // The system safe area already clears the Dynamic Island / status bar (adapting per device)
        // and reserves room for the floating Liquid Glass tab bar, so this fixed keypad screen just
        // lives inside it — no manual clearances or edge-to-edge overrides needed.
        VStack {
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
            ) {
                if let lastBookmarkedPricePer100g = viewModel.lastBookmarkedPricePer100g {
                    LastPriceChip(pricePer100g: lastBookmarkedPricePer100g) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            viewModel.clearBookmark()
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            inputZone.padding()
        }
        .frame(maxWidth: .infinity)
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
            VStack {
                CheckFieldsView(viewModel: viewModel, isShowingItemPicker: $isShowingItemPicker)
                KeypadView(viewModel: viewModel, onBookmark: viewModel.bookmarkCurrentPrice)
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
        case .scan:
            VStack {
                ScanModeView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
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
