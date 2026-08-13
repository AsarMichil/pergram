import SwiftUI

struct KeypadView: View {
    @Bindable var viewModel: CheckViewModel
    var onBookmark: (() -> Void)?

    private var canBookmark: Bool { viewModel.hasEnoughInput }

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 6) {
            GridRow {
                digitKey("1")
                digitKey("2")
                digitKey("3")
                DeleteKey(viewModel: viewModel)
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
                if let onBookmark {
                    bookmarkKey(onBookmark)
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: canBookmark)
    }

    private func bookmarkKey(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "bookmark")
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.glassProminent)
        .tint(canBookmark ? Color.accentColor : Color(.systemGray4))
        .disabled(!canBookmark)
    }

    private func digitKey(_ digit: String) -> some View {
        Button {
            viewModel.inputDigit(digit)
        } label: {
            keyLabel(Text(digit))
        }
        .buttonStyle(.glass)
    }

    private var decimalKey: some View {
        Button {
            viewModel.inputDecimalPoint()
        } label: {
            keyLabel(Text("."))
        }
        .buttonStyle(.glass)
    }

    private var clearKey: some View {
        Button {
            viewModel.clearFocusedField()
        } label: {
            keyLabel(Text("C"))
        }
        .buttonStyle(.glass)
    }

    private func keyLabel(_ text: Text) -> some View {
        text
            .font(.title2.weight(.medium))
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: 38)
    }
}

private struct DeleteKey: View {
    @Bindable var viewModel: CheckViewModel

    var body: some View {
        Image(systemName: "delete.left")
            .font(.title2.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 38)
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
                    }
                }
            )
    }
}

#Preview {
    KeypadView(viewModel: CheckViewModel(), onBookmark: {})
        .padding()
}
