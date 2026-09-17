import SwiftUI

/// The "$price per amount unit" entry card, shared by the Check screen and the Items add/edit sheet
/// so both drive one `CheckViewModel` through one keypad.
struct PriceExpressionCard: View {
    @Bindable var viewModel: CheckViewModel
    var metrics: CheckMetrics = .roomy

    var body: some View {
        VStack(spacing: metrics.stackSpacing) {
            priceField
            Divider()
            HStack(spacing: 8) {
                Text("per")
                    .foregroundStyle(.secondary)
                amountField
                unitMenu
            }
        }
        .padding(metrics.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.quaternary.opacity(0.25))
        }
    }

    private var priceField: some View {
        FieldBox(
            prefix: "$",
            text: viewModel.priceText,
            placeholder: "0.00",
            isFocused: viewModel.focusedField == .price,
            isSelected: viewModel.focusedField == .price && viewModel.isEditingFresh,
            font: metrics.emphasizedFieldFont,
            verticalPadding: metrics.fieldPadding,
            alignment: .leading
        )
        .onTapGesture { viewModel.focus(.price) }
        .accessibilityIdentifier("priceField")
    }

    private var amountField: some View {
        FieldBox(
            prefix: nil,
            text: viewModel.amountText,
            placeholder: "0",
            isFocused: viewModel.focusedField == .amount,
            isSelected: viewModel.focusedField == .amount && viewModel.isEditingFresh,
            font: metrics.fieldFont,
            verticalPadding: metrics.fieldPadding,
            alignment: .leading
        )
        .onTapGesture { viewModel.focus(.amount) }
        .accessibilityIdentifier("amountField")
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
            .padding(.vertical, metrics.fieldPadding)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.glass)
        .sensoryFeedback(.selection, trigger: viewModel.amountUnit)
    }

    private static func unitNoun(_ unit: MeasureUnit) -> String {
        switch unit {
        case .gram: return "g"
        case .kilogram: return "kg"
        case .pound: return "lb"
        case .ounce: return "oz"
        case .millilitre: return "mL"
        case .litre: return "L"
        case .each: return "ea"
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
    var font: Font
    var verticalPadding: CGFloat
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
        .font(font)
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(isFocused ? 0.5 : 0.25))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview("Roomy") {
    PriceExpressionCard(viewModel: CheckViewModel())
        .padding()
}

#Preview("Compact") {
    PriceExpressionCard(viewModel: CheckViewModel(), metrics: .compact)
        .padding()
}
