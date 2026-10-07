//
//  ProjectionStore.swift
//  iris
//

import AVFoundation
import Observation

/// What the TV shows, shared by the console (which writes it) and the external scene (which draws it).
/// The external scene is created by UIKit, so it reaches this through `shared`.
@Observable
final class ProjectionStore {
    static let shared = ProjectionStore()

    var frame: ProjectionFrame = .black
    /// Set while a video plays; the external scene draws it inside the canvas.
    var videoPlayer: AVPlayer?
    /// How the projected lyrics look (contract §6); the console and the TV both read this.
    var typography = ProjectionSettings()
    /// The connected external screen, `nil` without one.
    var display: ExternalDisplay? {
        didSet {
            guard display != oldValue else { return }
            for continuation in subscribers.values { continuation.yield(display) }
        }
    }

    @ObservationIgnored private var subscribers: [UUID: AsyncStream<ExternalDisplay?>.Continuation] = [:]

    func displayUpdates() -> AsyncStream<ExternalDisplay?> {
        let (stream, continuation) = AsyncStream.makeStream(of: ExternalDisplay?.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        subscribers[id] = continuation
        continuation.yield(display)
        continuation.onTermination = { _ in
            Task { @MainActor in ProjectionStore.shared.subscribers[id] = nil }
        }
        return stream
    }
}

/// `DisplayOutputService` over the real external display.
struct LiveDisplayOutputService: DisplayOutputService {
    var store: ProjectionStore = .shared

    func connectedDisplay() async -> ExternalDisplay? { store.display }

    func displayUpdates() -> AsyncStream<ExternalDisplay?> { store.displayUpdates() }

    func present(_ frame: ProjectionFrame) {
        store.frame = frame
    }

    var videoPlayer: AVPlayer? { store.videoPlayer }

    func setTypography(_ typography: ProjectionSettings) {
        store.typography = typography
    }
}
