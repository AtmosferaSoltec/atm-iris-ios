//
//  ServicePlanRepository.swift
//  iris
//

import Foundation

/// Source of service plans (local in V1, API later).
protocol ServicePlanRepository {
    func currentService() async throws -> ServicePlan
}

/// Source of projection backgrounds.
protocol BackgroundRepository {
    func backgrounds() async throws -> [ProjectionBackground]
}

/// Drives the external display (TV). V1 mocks it; a real implementation will
/// render `ProjectionCanvas` into an external `UIScene`.
protocol DisplayOutputService {
    func connectedDisplay() async -> ExternalDisplay?
    func present(_ frame: ProjectionFrame)
}
