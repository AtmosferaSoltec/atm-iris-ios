//
//  ServicePlanRepository.swift
//  iris
//

import AVFoundation
import Foundation

/// What any client (web, iPad, Windows) adelantó for the next service: songs and media, in order,
/// with no history by service (contract §15). A console that opens with nothing adelantado just
/// gets an empty list — the product rule that a service always starts blank still holds; this is
/// what the web (or another console) chose to have ready, not a saved history.
protocol ServicePlanRepository {
    /// Yields when the local copy of this data changes (a sync, another screen).
    func changes() -> AsyncStream<Void>
    func currentService() async throws -> ServicePlan
    /// Adds a song or media item and returns the id of its new row, to attach to the resulting
    /// `ServiceItem` (`planItemID`) so it can be moved or removed later.
    @discardableResult
    func add(kind: PlanItemKind, refID: String, label: String) async throws -> UUID
    /// Reorders; the rest shift to make room.
    func move(_ planItemID: UUID, to position: Int) async throws
    func remove(_ planItemID: UUID, label: String) async throws
    func clear() async throws
}

extension ServicePlanRepository {
    func changes() -> AsyncStream<Void> { .finished }
    @discardableResult
    func add(kind: PlanItemKind, refID: String, label: String) async throws -> UUID { UUID() }
    func move(_ planItemID: UUID, to position: Int) async throws {}
    func remove(_ planItemID: UUID, label: String) async throws {}
    func clear() async throws {}
}

/// A service started from Home always begins with an empty list (product rule): nothing is
/// adelantado until the web (or another console) puts something there.
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
    /// Mirrors the console's current typeface and size to the TV, which only has
    /// `ProjectionStore` to read from (it is a separate window, not a descendant of the console's
    /// view tree). The background needs no such mirroring: it already travels inside every
    /// `ProjectionFrame` the console presents.
    func setTypography(_ typography: ProjectionSettings)
}

extension DisplayOutputService {
    func setTypography(_ typography: ProjectionSettings) {}

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
