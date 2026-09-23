import SwiftUI

/// Renders the scan surface but does not own the camera. `CheckView` holds the `ScanModel` and
/// drives it from the selected mode, so the session's lifetime follows what the user picked rather
/// than when a view happened to appear. A capture session is far too costly to start, stop or
/// duplicate as a side effect of layout.
struct ScanModeView: View {
    let model: ScanModel
    let viewfinderHeight: CGFloat

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
            caption
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

    /// The slot is held open by the longer of the two captions whether or not there is anything to
    /// say, so neither the session starting nor a change of wording can move the viewfinder.
    private var caption: some View {
        Text(Self.adjustCaption)
            .hidden()
            .overlay {
                Text(captionText)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: captionText)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private static let aimCaption = "Aim at the shelf tag"
    private static let adjustCaption = "Swipe to Type to adjust"

    private var captionText: String {
        guard model.status == .scanning else { return "" }
        return model.hasFilled ? Self.adjustCaption : Self.aimCaption
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
