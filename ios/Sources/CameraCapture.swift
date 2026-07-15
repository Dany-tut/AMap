import SwiftUI
import AVFoundation

/// Live camera for the place card: owns an `AVCaptureSession`, exposes a preview
/// layer, and captures a still to JPEG `Data`. On the Simulator there's no
/// capture device, so `available` stays false and the UI shows a fallback.
@MainActor
final class CameraCapture: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "amaps.camera")
    private var configured = false

    @Published var available = false
    @Published var denied = false

    private var onCapture: ((Data) -> Void)?

    /// Configure once (requesting access as needed) and start the session.
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    granted ? self?.configureAndRun() : (self?.denied = true)
                }
            }
        default:
            denied = true
        }
    }

    private func configureAndRun() {
        if !configured {
            configured = true
            session.beginConfiguration()
            session.sessionPreset = .photo
            if let device = AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
                if session.canAddOutput(output) { session.addOutput(output) }
                available = true
            }
            session.commitConfiguration()
        }
        guard available else { return }
        let s = session
        queue.async { if !s.isRunning { s.startRunning() } }
    }

    func stop() {
        guard available else { return }
        let s = session
        queue.async { if s.isRunning { s.stopRunning() } }
    }

    /// Take a photo; `completion` fires on the main actor with JPEG data.
    func capture(_ completion: @escaping (Data) -> Void) {
        guard available else { return }
        onCapture = completion
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
}

extension CameraCapture: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in
            onCapture?(data)
            onCapture = nil
        }
    }
}

/// Hosts the camera's `AVCaptureVideoPreviewLayer` in SwiftUI.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ v: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
