//
//  ServicePlanRepository.swift
//  iris
//

import AVFoundation
import Foundation

/// Source of service plans (local in V1, API later).
protocol ServicePlanRepository {
    func currentService() async throws -> ServicePlan
}

/// A service started from Home always begins with an empty list (product rule): nothing is planned ahead in V1.
struct EmptyServicePlanRepository: ServicePlanRepository {
    var now: () -> Date = { .now }

    func currentService() async throws -> ServicePlan {
        ServicePlan(id: UUID(), title: String(localized: "Servicio"), date: now(), items: [])
    }
}

/// Source of projection backgrounds.
protocol BackgroundRepository {
    func backgrounds() async throws -> [ProjectionBackground]
}

/// Drives the external display (TV): `ProjectionCanvas` in an external, non-interactive scene.
protocol DisplayOutputService {
    func connectedDisplay() async -> ExternalDisplay?
    /// The current display, then every connection or disconnection, until the consuming task ends.
    func displayUpdates() -> AsyncStream<ExternalDisplay?>
    func present(_ frame: ProjectionFrame)
    /// The player of the video on the TV, so the console's live preview shows the same picture.
    var videoPlayer: AVPlayer? { get }
}

extension DisplayOutputService {
    func displayUpdates() -> AsyncStream<ExternalDisplay?> {
        AsyncStream { continuation in
            Task {
                continuation.yield(await connectedDisplay())
                continuation.finish()
            }
        }
    }

    var videoPlayer: AVPlayer? { nil }
}
