//
//  ExternalDisplayScene.swift
//  iris
//

import AVFoundation
import SwiftUI
import UIKit

/// Delegate of the non-interactive external display scene (HDMI or AirPlay in extended mode).
/// It shows only the projection, full screen, without any controls.
final class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let host = UIHostingController(rootView: ExternalProjectionView(store: .shared))
        host.view.backgroundColor = .black
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        ProjectionStore.shared.display = Self.describe(windowScene)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry
    ) {
        ProjectionStore.shared.display = Self.describe(windowScene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        ProjectionStore.shared.display = nil
    }

    /// "Pantalla externa · 1920 × 1080", or the AirPlay receiver's name when there is one.
    private static func describe(_ scene: UIWindowScene) -> ExternalDisplay {
        let size = scene.screen.nativeBounds.size
        let route = AVAudioSession.sharedInstance().currentRoute.outputs
            .first { $0.portType == .airPlay || $0.portType == .HDMI }
        let name = route?.portType == .airPlay ? route?.portName : nil
        return ExternalDisplay(
            name: name ?? String(localized: "Pantalla externa"),
            resolution: "\(Int(max(size.width, size.height))) × \(Int(min(size.width, size.height)))"
        )
    }
}

/// The TV: black, the projection centered at 16:9 with the same cross-fade as the console.
struct ExternalProjectionView: View {
    let store: ProjectionStore

    var body: some View {
        ZStack {
            Color.black
            ProjectionCanvas(frame: store.frame, cornerRadius: 0, isAnimated: true)
                .environment(\.projectionVideoPlayer, store.videoPlayer)
                .animation(IrisMotion.smooth, value: store.frame)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

extension EnvironmentValues {
    /// The player of the video being projected; `ProjectionCanvas` draws it in `.video` frames.
    @Entry var projectionVideoPlayer: AVPlayer?
}

/// `AVPlayerLayer` in SwiftUI, without controls.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
    }

    final class PlayerUIView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer {
            guard let layer = layer as? AVPlayerLayer else { fatalError("La capa de PlayerUIView siempre es AVPlayerLayer.") }
            return layer
        }
    }
}
