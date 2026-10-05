//
//  MockDisplayOutputService.swift
//  iris
//

import Foundation

/// Pretends a TV is connected and silently accepts frames.
struct MockDisplayOutputService: DisplayOutputService {
    func connectedDisplay() async -> ExternalDisplay? {
        ExternalDisplay(name: "Sala principal", resolution: "1920 × 1080")
    }

    func present(_ frame: ProjectionFrame) {
        // No external display in V1 mockups.
    }
}
