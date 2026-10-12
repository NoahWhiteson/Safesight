//
//  CameraScanView.swift
//  Safesight
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

final class CameraController: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationDenied = false
    @Published var capturedImage: UIImage?
    @Published var isSessionRunning = false
    @Published var isRecordingVideo = false

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "safesight.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private var movieContinuation: CheckedContinuation<URL?, Never>?
    private var recordingStartedAt: Date?
    private var autoStopTimer: DispatchWorkItem?

    func requestAccessAndConfigure() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await MainActor.run { isAuthorized = true }
            configureSession()
        case .notDetermined:
            let ok = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                isAuthorized = ok
                authorizationDenied = !ok
            }
            if ok { configureSession() }
        default:
            await MainActor.run {
                isAuthorized = false
                authorizationDenied = true
            }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            sessionQueue.async {
                let settings = AVCapturePhotoSettings()
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func startVideoRecording() {
        sessionQueue.async {
            guard !self.movieOutput.isRecording else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("safesight-\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: url)

            if let connection = self.movieOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }

            self.recordingStartedAt = Date()
            DispatchQueue.main.async { self.isRecordingVideo = true }

            let timer = DispatchWorkItem { [weak self] in
                self?.stopVideoRecordingInternal()
            }
            self.autoStopTimer = timer
            self.sessionQueue.asyncAfter(deadline: .now() + VideoScanPipeline.maxRecordSeconds, execute: timer)

            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopVideoRecording() async -> URL? {
        await withCheckedContinuation { continuation in
            self.movieContinuation = continuation
            sessionQueue.async {
                self.stopVideoRecordingInternal()
            }
        }
    }

    private func stopVideoRecordingInternal() {
        autoStopTimer?.cancel()
        autoStopTimer = nil
        guard movieOutput.isRecording else {
            DispatchQueue.main.async {
                self.isRecordingVideo = false
                self.movieContinuation?.resume(returning: nil)
                self.movieContinuation = nil
            }
            return
        }
        movieOutput.stopRecording()
    }

    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.high) {
                self.session.sessionPreset = .high
            } else {
                self.session.sessionPreset = .photo
            }

            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                if let connection = self.photoOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }

            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
                if let connection = self.movieOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }

            self.session.commitConfiguration()
        }
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isRecordingVideo = false
            self.recordingStartedAt = nil
            if error != nil {
                self.movieContinuation?.resume(returning: nil)
            } else {
                self.movieContinuation?.resume(returning: outputFileURL)
            }
            self.movieContinuation = nil
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image: UIImage?
        if let data = photo.fileDataRepresentation() {
            image = UIImage(data: data)
        } else {
            image = nil
        }
        DispatchQueue.main.async {
            self.capturedImage = image
            self.continuation?.resume(returning: image)
            self.continuation = nil
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Full-bleed capture + Apple Intelligence edge glow (flush to screen edge).
struct ScanThinkingOverlay: View {
    let image: UIImage

    var body: some View {
        AppleIntelligenceThinkingChrome(image: image)
    }
}

extension UIImage {
    /// Bake EXIF orientation into pixel buffer so overlays match Gemini boxes.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
