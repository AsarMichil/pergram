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
        VStack(spacing: 12) {
            VStack(spacing: 16) {
                ModeBubble(mode: $mode)

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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            inputZone
                .padding(.horizontal)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .simultaneousGesture(modeSwipe)
        .sensoryFeedback(.selection, trigger: mode)
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
