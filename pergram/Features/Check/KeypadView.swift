import SwiftUI

struct KeypadView: View {
    @Bindable var viewModel: CheckViewModel

    private static let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "delete"],
    ]

    @State private var digitTick = 0

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Self.rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        keyView(for: key)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: digitTick)
    }

    @ViewBuilder
    private func keyView(for key: String) -> some View {
        switch key {
        case "delete":
            DeleteKey(viewModel: viewModel, digitTick: $digitTick)
        case ".":
            Button {
                viewModel.inputDecimalPoint()
                digitTick &+= 1
            } label: {
                keyLabel(".")
            }
            .buttonStyle(.glass)
        default:
            Button {
                viewModel.inputDigit(key)
                digitTick &+= 1
            } label: {
                keyLabel(key)
            }
            .buttonStyle(.glass)
        }
    }

    private func keyLabel(_ text: String) -> some View {
        Text(text)
            .font(.title2.weight(.medium))
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: 48)
    }
}

private struct DeleteKey: View {
    @Bindable var viewModel: CheckViewModel
    @Binding var digitTick: Int

    var body: some View {
        Image(systemName: "delete.left")
            .font(.title2.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 48)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            .contentShape(Rectangle())
            .onLongPressGesture(
                minimumDuration: 0.35,
                maximumDistance: 30,
                perform: {
                    viewModel.deleteKeyLongPressRecognized()
                },
                onPressingChanged: { pressing in
                    if pressing {
                        viewModel.deleteKeyPressStarted()
                    } else {
                        viewModel.deleteKeyPressEnded()
                        digitTick &+= 1
                    }
                }
            )
    }
}

#Preview {
    KeypadView(viewModel: CheckViewModel())
        .padding()
}
