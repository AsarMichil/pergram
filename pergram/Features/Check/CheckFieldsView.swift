import SwiftUI

struct CheckFieldsView: View {
    @Bindable var viewModel: CheckViewModel
    let selectedItemName: String?
    @Binding var isShowingItemPicker: Bool

    var body: some View {
        VStack {
            PriceExpressionCard(viewModel: viewModel)
            itemChip
        }
    }

    private var itemChip: some View {
        Button {
            isShowingItemPicker = true
        } label: {
            HStack {
                Image(systemName: "tag")
                Text(selectedItemName ?? "No item selected")
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
    }
}

#Preview {
    CheckFieldsView(
        viewModel: CheckViewModel(), selectedItemName: nil, isShowingItemPicker: .constant(false)
    )
    .padding()
}
