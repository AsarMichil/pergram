import SwiftData
import SwiftUI

struct CheckView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CheckViewModel()
    @State private var isShowingItemPicker = false
    @State private var isShowingSaveSheet = false

    var body: some View {
        VStack(spacing: 16) {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 14) {
                CheckFieldsView(viewModel: viewModel, isShowingItemPicker: $isShowingItemPicker)
                KeypadView(viewModel: viewModel)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 52)
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
