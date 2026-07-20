import SwiftUI

struct CheckFieldsView: View {
    @Bindable var viewModel: CheckViewModel
    @Binding var isShowingItemPicker: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                priceField
                quantityStepper
            }
            HStack(spacing: 10) {
                amountField
                unitMenu
            }
            itemChip
        }
    }

    private var priceField: some View {
        FieldBox(
            prefix: "$",
            text: viewModel.priceText,
            placeholder: "0.00",
            isFocused: viewModel.focusedField == .price
        )
        .onTapGesture {
            viewModel.focusedField = .price
        }
    }

    private var amountField: some View {
        FieldBox(
            prefix: nil,
            text: viewModel.amountText,
            placeholder: "amount",
            isFocused: viewModel.focusedField == .amount
        )
        .onTapGesture {
            viewModel.focusedField = .amount
        }
    }

    private var unitMenu: some View {
        Menu {
            ForEach(MeasureUnit.allCases, id: \.self) { unit in
                Button(PriceDisplay.amountUnitLabel(for: unit)) {
                    viewModel.amountUnit = unit
                }
            }
        } label: {
            Text(PriceDisplay.amountUnitLabel(for: viewModel.amountUnit))
                .font(.body.weight(.medium))
                .frame(minWidth: 64)
                .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
        .sensoryFeedback(.selection, trigger: viewModel.amountUnit)
    }

    private var quantityStepper: some View {
        HStack(spacing: 6) {
            Stepper(value: $viewModel.quantityCount, in: 1...20) {
                Text(viewModel.quantityCount == 1 ? "1 for" : "\(viewModel.quantityCount) for")
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
            }
        }
        .fixedSize()
        .sensoryFeedback(.selection, trigger: viewModel.quantityCount)
    }

    private var itemChip: some View {
        Button {
            isShowingItemPicker = true
        } label: {
            HStack {
                Image(systemName: "tag")
                Text(viewModel.selectedItem?.name ?? "No item selected")
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

private struct FieldBox: View {
    let prefix: String?
    let text: String
    let placeholder: String
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 2) {
            if let prefix {
                Text(prefix)
                    .foregroundStyle(.secondary)
            }
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
            } else {
                Text(text)
            }
        }
        .font(.title3.weight(.semibold))
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(isFocused ? 0.6 : 0.3))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}

#Preview {
    CheckFieldsView(viewModel: CheckViewModel(), isShowingItemPicker: .constant(false))
        .padding()
}
