//
//  QRScannerView.swift
//  iris
//

import AVFoundation
import SwiftUI
import UIKit

/// Camera viewfinder that reports every QR code it reads (the same code can arrive many times a second:
/// the caller decides what to ignore).
struct QRScannerView: UIViewControllerRepresentable {
    /// Scanning only while there is nothing paired or being paired: the camera stops the moment a connection starts.
    let isActive: Bool
    let onCode: (String) -> Void
    /// The session could not start (no camera, camera in use).
    let onUnavailable: () -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onCode = onCode
        controller.onUnavailable = onUnavailable
        controller.setActive(isActive)
        return controller
    }

    static func dismantleUIViewController(_ controller: QRScannerController, coordinator: ()) {
        controller.setActive(false)
    }

    func updateUIViewController(_ controller: QRScannerController, context: Context) {
        controller.onCode = onCode
        controller.onUnavailable = onUnavailable
        controller.setActive(isActive)
    }
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onUnavailable: (() -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "iris.qr-scanner")
    private var preview: AVCaptureVideoPreviewLayer?
    private var isConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        preview = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
        if let connection = preview?.connection, connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }

    /// The viewfinder follows the interface so the picture is never sideways.
    private var rotationAngle: CGFloat {
        switch view.window?.windowScene?.effectiveGeometry.interfaceOrientation {
        case .landscapeLeft: 180
        case .landscapeRight: 0
        case .portraitUpsideDown: 270
        default: 90
        }
    }

    private var isActive = true

    func setActive(_ active: Bool) {
        isActive = active
        guard isViewLoaded else { return }
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured else { return }
            if active, !self.session.isRunning { self.session.startRunning() }
            if !active, self.session.isRunning { self.session.stopRunning() }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured { self.configure() }
            if self.isConfigured, self.isActive, !self.session.isRunning { self.session.startRunning() }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sessionQueue.async { [weak self] in
            if self?.session.isRunning == true { self?.session.stopRunning() }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return unavailable() }
        let output = AVCaptureMetadataOutput()
        session.beginConfiguration()
        session.addInput(input)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return unavailable()
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = output.availableMetadataObjectTypes.contains(.qr) ? [.qr] : []
        session.commitConfiguration()
        isConfigured = true
    }

    private func unavailable() {
        DispatchQueue.main.async { [weak self] in self?.onUnavailable?() }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput objects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard isActive else { return }
        for case let code as AVMetadataMachineReadableCodeObject in objects {
            if let text = code.stringValue { onCode?(text) }
        }
    }
}
