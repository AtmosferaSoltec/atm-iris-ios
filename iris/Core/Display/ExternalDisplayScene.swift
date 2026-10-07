//
//  ExternalDisplayScene.swift
//  iris
//
//  The TV. Since iOS 27 the system gives an app the external screen (HDMI or AirPlay) only while the
//  app registers a scene accessory for it; without one it mirrors the iPad, controls included.
//  The app's root view registers it with `projectionOnExternalDisplay()`, so the TV shows only the projection.
//

import AVFoundation
import OSLog
import SwiftUI
import UIKit

private let log = Logger(subsystem: "com.atm.iris", category: "TV")

extension View {
    /// Offers the projection to the external display for as long as this view is on screen.
    /// Attach it once, to the app's root view, so the TV never falls back to mirroring the iPad.
    func projectionOnExternalDisplay(store: ProjectionStore = .shared) -> some View {
        sceneAccessory {
            ExternalNonInteractiveAccessory {
                ExternalProjectionView(store: store)
            }
            // The system may withdraw the accessory (display unplugged, AirPlay stopped).
            .onAvailabilityChange { isAvailable in
                log.notice("Pantalla externa \(isAvailable ? "disponible" : "no disponible", privacy: .public)")
                if !isAvailable { store.display = nil }
            }
        }
    }
}

/// The TV: black, the projection centered at 16:9 with the same cross-fade as the console.
/// Non-interactive: everything is controlled from the iPad.
struct ExternalProjectionView: View {
    let store: ProjectionStore

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            Color.black
            ProjectionCanvas(frame: store.frame, cornerRadius: 0, isAnimated: true, typography: store.typography)
                .environment(\.projectionVideoPlayer, store.videoPlayer)
                .animation(IrisMotion.smooth, value: store.frame)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // Being drawn on the TV is what "connected" means for the console's TV chip.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            let display = ExternalDisplay.describe(pointSize: size, scale: displayScale)
            log.notice("Proyectando en \(display.name, privacy: .public) · \(display.resolution, privacy: .public)")
            store.display = display
        }
        .onDisappear {
            log.notice("La pantalla externa dejó de mostrar la proyección")
            store.display = nil
        }
    }
}

extension ExternalDisplay {
    /// "Pantalla externa · 1920 × 1080", or the AirPlay receiver's name when there is one.
    static func describe(pointSize size: CGSize, scale: CGFloat) -> ExternalDisplay {
        let route = AVAudioSession.sharedInstance().currentRoute.outputs
            .first { $0.portType == .airPlay || $0.portType == .HDMI }
        let name = route?.portType == .airPlay ? route?.portName : nil
        let width = Int((max(size.width, size.height) * scale).rounded())
        let height = Int((min(size.width, size.height) * scale).rounded())
        return ExternalDisplay(
            name: name ?? String(localized: "Pantalla externa"),
            resolution: "\(width) × \(height)"
        )
    }
}

extension EnvironmentValues {
    /// The player of the video being projected; `ProjectionCanvas` draws it in `.video` frames.
    @Entry var projectionVideoPlayer: AVPlayer?
}

/// `AVPlayerLayer` in SwiftUI, without controls.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    /// `.resizeAspect` for a slide's own video (never cropped); `.resizeAspectFill` for a
    /// background video (fills the 16:9 canvas edge to edge, like a background image).
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = gravity
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
