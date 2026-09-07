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

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "safesight.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage?, Never>?

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

    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input),
                self.session.canAddOutput(self.photoOutput)
            else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)
            self.session.addOutput(self.photoOutput)
            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            self.session.commitConfiguration()
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
