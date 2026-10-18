import SwiftUI

/// Renders the scan surface but does not own the camera. `CheckView` holds the `ScanModel` and
/// drives it from the selected mode, so the session's lifetime follows what the user picked rather
/// than when a view happened to appear. A capture session is far too costly to start, stop or
/// duplicate as a side effect of layout.
struct ScanModeView: View {
    let model: ScanModel
    let viewfinderHeight: CGFloat
    /// The item or list entry being priced. Scan has no item row, so the caption is the only place
    /// that says what a scan will be judged against.
    var selectionName: String?
    var canBookmark = false
    var canAddToCart = false
    var onBookmark: (() -> Void)?
    var onAddToCart: (() -> Void)?

    @State private var focusPoint: CGPoint?
    @State private var focusTick = 0
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack {
            // A fixed height and the full width it is given: the card takes the space rather than a
            // ratio, and its height cannot depend on what is inside it, so it is the same size
            // before and after the session starts. `CheckView` tells the recognizer what shape this
            // came out as, because the crop Vision reads has to match what is on screen.
            viewfinder
                .frame(
                    maxWidth: .infinity, minHeight: viewfinderHeight, maxHeight: viewfinderHeight
                )
                .clipShape(RoundedRectangle(cornerRadius: 28))
            // The caption row reserves a full target (`CheckMetrics.captionAllowance`), so the
            // actions sit beside it without costing the viewfinder any height. They pair at the
            // trailing edge in the keypad's order, cart outermost, so both modes keep them under the
            // same thumb.
            HStack(spacing: 12) {
                caption
                    .frame(maxWidth: .infinity, alignment: .leading)
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        actionButton(
                            "Park this price to compare against", systemImage: "bookmark",
                            identifier: "scanBookmark", isEnabled: canBookmark, action: onBookmark)
                        actionButton(
                            "Add to cart", systemImage: "cart.badge.plus",
                            identifier: "scanAddToCart", isEnabled: canAddToCart,
                            action: onAddToCart)
                    }
                }
            }
            .padding(.leading, 4)
            .frame(height: CheckMetrics.captionAllowance)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.filledTick)
    }

    @ViewBuilder
    private var viewfinder: some View {
        switch model.status {
        case .scanning:
            if let session = model.session {
                ZStack {
                    CameraPreview(
                        session: session,
                        onFocusTap: { devicePoint, viewPoint in
                            model.focus(at: devicePoint)
                            focusPoint = viewPoint
                            focusTick += 1
                        },
                        onZoomBegan: model.beginZoom,
                        onZoomChanged: model.zoom(by:)
                    )
                    Reticle()
                        .stroke(
                            .white.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .padding(28)
                    if let focusPoint {
                        FocusIndicator()
                            .position(focusPoint)
                            .transition(.opacity.combined(with: .scale(scale: 1.3)))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: focusPoint)
                .task(id: focusTick) {
                    guard focusPoint != nil else { return }
                    try? await Task.sleep(for: .seconds(1))
                    focusPoint = nil
                }
            }
        case .denied:
            unavailablePanel("Camera access is off", systemImage: "camera.badge.ellipsis") {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.glass)
            }
        case .unavailable:
            unavailablePanel("No camera on this device", systemImage: "camera.badge.ellipsis") {
                EmptyView()
            }
        case .starting:
            // A bare panel here is indistinguishable from a hang, which is exactly the confusion to
            // avoid while the session spins up.
            RoundedRectangle(cornerRadius: 28)
                .fill(.quaternary.opacity(0.25))
                .overlay { ProgressView() }
        case .idle:
            RoundedRectangle(cornerRadius: 28).fill(.quaternary.opacity(0.25))
        }
    }

    private var caption: some View {
        Text(selectionName ?? "")
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
    }

    @ViewBuilder
    private func actionButton(
        _ label: String, systemImage: String, identifier: String, isEnabled: Bool,
        action: (() -> Void)?
    ) -> some View {
        if let action {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isEnabled ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .frame(width: 44, height: 44)
                    .glassEffect(
                        isEnabled ? .regular.tint(.accentColor).interactive() : .regular,
                        in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .animation(.easeInOut(duration: 0.3), value: isEnabled)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
        }
    }

    private func unavailablePanel<Action: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            action()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary.opacity(0.25))
    }
}

/// The only confirmation that a tap registered, since a focus pull is often invisible on a flat
/// shelf tag.
private struct FocusIndicator: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(.yellow.opacity(0.9), lineWidth: 1.5)
            .frame(width: 64, height: 64)
            .allowsHitTesting(false)
    }
}

private struct Reticle: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.14
        var path = Path()
        for corner in [
            (CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0),
            (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
            (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0),
        ] {
            let (origin, dx, dy) = corner
            path.move(to: CGPoint(x: origin.x, y: origin.y + length * dy))
            path.addLine(to: origin)
            path.addLine(to: CGPoint(x: origin.x + length * dx, y: origin.y))
        }
        return path
    }
}

#Preview {
    ScanModeView(model: ScanModel(), viewfinderHeight: 360)
        .padding()
}
