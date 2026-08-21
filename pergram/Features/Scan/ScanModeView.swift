import SwiftUI

struct ScanModeView: View {
    var onCandidate: (ScanCandidate) -> Void

    @State private var model = ScanModel()
    @State private var focusPoint: CGPoint?
    @State private var focusTick = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack {
            viewfinder
                .aspectRatio(ShelfTagRecognizer.previewAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28))
            caption
        }
        .onAppear {
            model.onCandidate = onCandidate
            model.start()
        }
        .onDisappear { model.stop() }
        // Only `.background` stops the session. `.inactive` also fires for the camera permission
        // alert, Control Centre and the notification shade — tearing the session down and rebuilding
        // it on the way back churns the capture pipeline for no reason.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.start()
            case .background: model.stop()
            default: break
            }
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
        case .idle, .starting:
            RoundedRectangle(cornerRadius: 28).fill(.quaternary.opacity(0.25))
        }
    }

    @ViewBuilder
    private var caption: some View {
        if model.status == .scanning {
            Text(model.hasFilled ? "Swipe to Type to adjust" : "Aim at the shelf tag")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: model.hasFilled)
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

/// The square every camera app draws where you tapped. It is the only confirmation that the tap
/// registered, since a focus pull is often invisible on a flat shelf tag.
private struct FocusIndicator: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(.yellow.opacity(0.9), lineWidth: 1.5)
            .frame(width: 64, height: 64)
            .allowsHitTesting(false)
    }
}

/// Four corner brackets — enough to say "aim here" without boxing the picture in.
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
    ScanModeView { _ in }
        .padding()
}
