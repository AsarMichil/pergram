import SwiftUI

struct KeypadView: View {
    @Bindable var viewModel: CheckViewModel
    @State private var tick = 0

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                digitKey("1")
                digitKey("2")
                digitKey("3")
                DeleteKey(viewModel: viewModel, digitTick: $tick)
            }
            GridRow {
                digitKey("4")
                digitKey("5")
                digitKey("6")
                clearKey
            }
            GridRow {
                digitKey("7")
                digitKey("8")
                digitKey("9")
                decimalKey
            }
            GridRow {
                digitKey("0")
                    .gridCellColumns(3)
                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
        .sensoryFeedback(.selection, trigger: tick)
    }

    private func digitKey(_ digit: String) -> some View {
        Button {
            viewModel.inputDigit(digit)
            tick &+= 1
        } label: {
            keyLabel(Text(digit))
        }
        .buttonStyle(.glass)
    }

    private var decimalKey: some View {
        Button {
            viewModel.inputDecimalPoint()
            tick &+= 1
        } label: {
            keyLabel(Text("."))
        }
        .buttonStyle(.glass)
    }

    private var clearKey: some View {
        Button {
            viewModel.clearFocusedField()
            tick &+= 1
        } label: {
            keyLabel(Text("C"))
        }
        .buttonStyle(.glass)
    }

    private func keyLabel(_ text: Text) -> some View {
        text
            .font(.title2.weight(.medium))
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: 46)
    }
}

private struct DeleteKey: View {
    @Bindable var viewModel: CheckViewModel
    @Binding var digitTick: Int

    var body: some View {
        Image(systemName: "delete.left")
            .font(.title2.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 46)
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
