import SwiftUI

struct KeypadView: View {
    @Bindable var viewModel: CheckViewModel
    var onBookmark: (() -> Void)?
    var metrics: CheckMetrics = .roomy

    private var canBookmark: Bool { viewModel.hasEnoughInput }

    var body: some View {
        Grid(horizontalSpacing: metrics.keySpacing, verticalSpacing: metrics.keySpacing) {
            GridRow {
                digitKey("1")
                digitKey("2")
                digitKey("3")
                DeleteKey(viewModel: viewModel, metrics: metrics)
            }
            GridRow {
                digitKey("4")
                digitKey("5")
                digitKey("6")
                decimalKey
            }
            GridRow {
                digitKey("7")
                digitKey("8")
                digitKey("9")
                if let onBookmark {
                    bookmarkKey(onBookmark)
                } else {
                    Color.clear
                }
            }
            GridRow {
                digitKey("0")
                    .gridCellColumns(4)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: canBookmark)
    }

    private func digitKey(_ digit: String) -> some View {
        Button {
            viewModel.inputDigit(digit)
        } label: {
            KeyFace(metrics: metrics) { Text(digit).monospacedDigit() }
        }
        .buttonStyle(.plain)
    }

    private var decimalKey: some View {
        Button {
            viewModel.inputDecimalPoint()
        } label: {
            KeyFace(metrics: metrics) { Text(".") }
        }
        .buttonStyle(.plain)
    }

    private func bookmarkKey(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KeyFace(metrics: metrics, tint: canBookmark ? .accentColor : Color(.systemGray4)) {
                Image(systemName: "bookmark")
            }
        }
        .buttonStyle(.plain)
        .disabled(!canBookmark)
        .accessibilityLabel("Park this price to compare against")
        .accessibilityIdentifier("bookmarkKey")
    }
}

/// A key draws at `metrics.keyHeight` but takes touches out to `metrics.minimumKeyHeight`, by
/// claiming half the grid gap on each side. The padding pair is what separates the two: the first
/// grows the bounds the content shape is measured from, the second gives the layout its height back
/// so the gap is borrowed for touch rather than spent twice.
private struct KeyFace<Label: View>: View {
    let metrics: CheckMetrics
    var tint: Color?
    @ViewBuilder var label: Label

    var body: some View {
        label
            .font(.title2.weight(.medium))
            .foregroundStyle(tint == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .frame(maxWidth: .infinity, minHeight: metrics.keyHeight)
            .glassEffect(glass, in: .rect(cornerRadius: 14))
            .padding(.vertical, metrics.keyTouchInset)
            .contentShape(.rect)
            .padding(.vertical, -metrics.keyTouchInset)
    }

    private var glass: Glass {
        guard let tint else { return .regular.interactive() }
        return .regular.tint(tint).interactive()
    }
}

private struct DeleteKey: View {
    @Bindable var viewModel: CheckViewModel
    let metrics: CheckMetrics

    var body: some View {
        KeyFace(metrics: metrics) { Image(systemName: "delete.left") }
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
            .accessibilityLabel("Delete. Hold to clear.")
    }
}

#Preview("Roomy") {
    KeypadView(viewModel: CheckViewModel(), onBookmark: {})
        .padding()
}

#Preview("Compact") {
    KeypadView(viewModel: CheckViewModel(), onBookmark: {}, metrics: .compact)
        .padding()
}

#Preview("No bookmark") {
    KeypadView(viewModel: CheckViewModel(), onBookmark: nil)
        .padding()
}
