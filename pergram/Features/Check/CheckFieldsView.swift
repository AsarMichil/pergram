import SwiftUI

struct CheckFieldsView: View {
    @Bindable var viewModel: CheckViewModel
    @Binding var isShowingItemPicker: Bool

    var body: some View {
        VStack(spacing: 12) {
            expressionCard
            itemChip
        }
    }

    private var expressionCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                quantityControl
                Spacer(minLength: 8)
                priceField
            }
            Divider()
            HStack(spacing: 8) {
                Text("per")
                    .foregroundStyle(.secondary)
                amountField
                unitMenu
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.quaternary.opacity(0.25))
        }
    }

    private var quantityControl: some View {
        HStack(spacing: 8) {
            Button {
                adjustQuantity(-1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.glass)
            .disabled(viewModel.quantityCount <= 1)

            Text("\(viewModel.quantityCount) for")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())

            Button {
                adjustQuantity(1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.glass)
        }
        .sensoryFeedback(.selection, trigger: viewModel.quantityCount)
    }

    private var priceField: some View {
        FieldBox(
            prefix: "$",
            text: viewModel.priceText,
            placeholder: "0.00",
            isFocused: viewModel.focusedField == .price,
            isSelected: viewModel.focusedField == .price && viewModel.isEditingFresh,
            emphasized: true,
            alignment: .trailing
        )
        .frame(maxWidth: 150)
        .onTapGesture { viewModel.focus(.price) }
    }

    private var amountField: some View {
        FieldBox(
            prefix: nil,
            text: viewModel.amountText,
            placeholder: "0",
            isFocused: viewModel.focusedField == .amount,
            isSelected: viewModel.focusedField == .amount && viewModel.isEditingFresh,
            emphasized: false,
            alignment: .leading
        )
        .onTapGesture { viewModel.focus(.amount) }
    }

    private var unitMenu: some View {
        Menu {
            ForEach(CheckViewModel.amountUnits, id: \.self) { unit in
                Button(Self.unitNoun(unit)) { viewModel.amountUnit = unit }
            }
        } label: {
            HStack(spacing: 3) {
                Text(Self.unitNoun(viewModel.amountUnit))
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.glass)
        .sensoryFeedback(.selection, trigger: viewModel.amountUnit)
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

    private func adjustQuantity(_ delta: Int) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            viewModel.quantityCount = min(20, max(1, viewModel.quantityCount + delta))
        }
    }

    private static func unitNoun(_ unit: MeasureUnit) -> String {
        switch unit {
        case .gram: return "g"
        case .kilogram: return "kg"
        case .pound: return "lb"
        case .ounce: return "oz"
        default: return unit.rawValue
        }
    }
}

private struct FieldBox: View {
    let prefix: String?
    let text: String
    let placeholder: String
    let isFocused: Bool
    let isSelected: Bool
    var emphasized = false
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        HStack(spacing: 2) {
            if let prefix {
                Text(prefix)
                    .foregroundStyle(.secondary)
            }
            Group {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(text)
                }
            }
            .padding(.horizontal, isSelected && !text.isEmpty ? 3 : 0)
            .background {
                if isSelected && !text.isEmpty {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.accentColor.opacity(0.3))
                }
            }
        }
        .font(emphasized ? .title2.weight(.bold) : .title3.weight(.semibold))
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(isFocused ? 0.5 : 0.25))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    CheckFieldsView(viewModel: CheckViewModel(), isShowingItemPicker: .constant(false))
        .padding()
}
