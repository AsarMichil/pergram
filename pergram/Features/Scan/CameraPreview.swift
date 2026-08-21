import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Reports the tap twice over: once in the device's coordinate space for the focus call, once
    /// in the view's for the indicator drawn on top.
    var onFocusTap: (_ devicePoint: CGPoint, _ viewPoint: CGPoint) -> Void = { _, _ in }
    var onZoomBegan: () -> Void = {}
    var onZoomChanged: (CGFloat) -> Void = { _ in }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {
        view.pinToPortrait()
        view.onFocusTap = onFocusTap
        view.onZoomBegan = onZoomBegan
        view.onZoomChanged = onZoomChanged
    }
}

/// Gestures live here rather than in SwiftUI because the tap has to be converted through
/// `AVCaptureVideoPreviewLayer` — it is the only thing that knows how `.resizeAspectFill` cropped
/// the frame, and getting that wrong focuses on the wrong part of the shelf.
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var onFocusTap: (CGPoint, CGPoint) -> Void = { _, _ in }
    var onZoomBegan: () -> Void = {}
    var onZoomChanged: (CGFloat) -> Void = { _ in }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinch)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The app is locked to portrait, so the preview is pinned rather than tracked with a rotation
    /// coordinator — following gravity would tilt the picture inside a UI that never rotates. The
    /// connection only exists once the session has an input, hence setting it on every update.
    func pinToPortrait() {
        guard let connection = previewLayer.connection,
            connection.isVideoRotationAngleSupported(90)
        else { return }
        connection.videoRotationAngle = 90
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let viewPoint = gesture.location(in: self)
        onFocusTap(previewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint), viewPoint)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began: onZoomBegan()
        case .changed: onZoomChanged(gesture.scale)
        default: break
        }
    }
}
