//
//  PairingScreen.swift
//  iris
//

import AVFoundation
import SwiftUI
import UIKit

/// First screen, every time the app opens: scan the QR that Iris shows on the computer. Nothing is typed.
struct PairingScreen: View {
    let client: RemoteClient

    private enum Camera { case checking, allowed, denied, unavailable }

    @State private var camera: Camera = .checking
    /// The error on screen right now; it goes away after a few seconds or with a tap.
    @State private var notice: String?
    /// The same QR is read many times a second: a rejected one is said once, not every frame.
    @State private var lastRejected: (text: String, date: Date)?
    @Environment(\.openURL) private var openURL

    private var isConnecting: Bool { client.phase == .connecting }

    var body: some View {
        VStack(spacing: IrisSpacing.lg) {
            IrisWordmark(markSize: 44)

            IrisSurface(padding: IrisSpacing.xl) {
                VStack(spacing: IrisSpacing.lg) {
                    VStack(spacing: IrisSpacing.xs) {
                        Text("Conecta con Iris")
                            .font(IrisFont.title)
                        Text("Escanea el código QR que aparece en Iris en tu computadora.")
                            .font(IrisFont.callout)
                            .foregroundStyle(IrisColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    viewfinder
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)
                                .strokeBorder(IrisColor.stroke, lineWidth: 1)
                        )
                }
            }
            .frame(width: IrisSize.authPanelWidth)

            Text("La computadora y el iPad deben estar en la misma red Wi-Fi.")
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.textSecondary)
        }
        .padding(IrisSpacing.lg)
        // Floating, so a long message never pushes the viewfinder around; it leaves by itself.
        .overlay(alignment: .top) {
            if let notice {
                IrisBanner(style: .error, message: notice)
                    .background(IrisColor.canvasElevated, in: RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                    .frame(maxWidth: 560)
                    .padding(.top, IrisSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation(IrisMotion.snappy) { self.notice = nil } }
            }
        }
        .animation(IrisMotion.snappy, value: notice)
        .task(id: notice) {
            guard notice != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            withAnimation(IrisMotion.snappy) { notice = nil }
        }
        .onChange(of: client.failureMessage) { _, message in
            if let message { notice = message }
        }
        .task { await checkCamera() }
        .onAppear { if let message = client.failureMessage { notice = message } }
    }

    // MARK: Viewfinder

    @ViewBuilder
    private var viewfinder: some View {
        switch camera {
        case .checking:
            Color.black.overlay(ProgressView())
        case .allowed:
            ZStack {
                QRScannerView(onCode: handle, onUnavailable: { camera = .unavailable })
                if isConnecting {
                    Color.black.opacity(0.65)
                    HStack(spacing: IrisSpacing.xs) {
                        ProgressView()
                        Text("Conectando con Iris…").font(IrisFont.calloutEmphasized)
                    }
                }
            }
        case .denied:
            message(
                icon: "camera.fill",
                text: "Iris necesita la cámara para escanear el código QR. Actívala en Ajustes del iPad → Iris → Cámara.",
                action: ("Abrir Ajustes", openSettings)
            )
        case .unavailable:
            message(icon: "camera.fill", text: "No pudimos usar la cámara de este iPad.", action: nil)
        }
    }

    private func message(icon: String, text: String, action: (title: String, run: () -> Void)?) -> some View {
        VStack(spacing: IrisSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(IrisColor.textSecondary)
            Text(text)
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(action.title, action: action.run).buttonStyle(.irisPrimary)
            }
        }
        .padding(IrisSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IrisColor.surface)
    }

    // MARK: Logic

    private func checkCamera() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            camera = .allowed
        case .notDetermined:
            camera = await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .denied
        default:
            camera = .denied
        }
        // Back from Settings with the permission granted.
        while camera == .denied {
            try? await Task.sleep(for: .seconds(1))
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { camera = .allowed }
        }
    }

    private func handle(_ text: String) {
        guard !isConnecting else { return }
        switch PairingLink.parse(text) {
        case .success(let link):
            client.connect(link: link)
        case .failure(let failure):
            if let last = lastRejected, last.text == text, Date().timeIntervalSince(last.date) < 4 { return }
            lastRejected = (text, Date())
            notice = failure.message
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

#Preview {
    ZStack {
        IrisBackground().ignoresSafeArea()
        PairingScreen(client: RemoteClient())
    }
    .preferredColorScheme(.dark)
}
