import AVFoundation
import Combine
import UIKit

/// Captures video frames from the phone's back camera for use when glasses aren't connected.
@MainActor
class PhoneCameraCapture: ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var isRunning: Bool = false
    @Published var errorMessage: String?

    private let captureQueue = DispatchQueue(label: "com.medkit.phonecamera")
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var videoOutputDelegate: VideoOutputDelegate?

    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func start() {
        guard captureSession == nil else {
            captureSession?.startRunning()
            isRunning = true
            return
        }

        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            errorMessage = "No back camera available."
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            errorMessage = "Could not create camera input: \(error.localizedDescription)"
            return
        }

        let delegate = VideoOutputDelegate { [weak self] image in
            Task { @MainActor in
                self?.currentFrame = image
            }
        }
        videoOutputDelegate = delegate

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(delegate, queue: captureQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        videoOutput = output

        captureQueue.async {
            session.startRunning()
        }
        captureSession = session
        isRunning = true
        errorMessage = nil
    }

    func stop() {
        captureSession?.stopRunning()
        isRunning = false
        currentFrame = nil
        videoOutput?.setSampleBufferDelegate(nil, queue: captureQueue)
        videoOutputDelegate = nil
    }
}

private class VideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let onFrame: (UIImage) -> Void

    init(onFrame: @escaping (UIImage) -> Void) {
        self.onFrame = onFrame
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
        onFrame(image)
    }
}
