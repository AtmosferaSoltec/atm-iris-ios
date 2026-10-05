//
//  MockBackgroundRepository.swift
//  iris
//

import Foundation

struct MockBackgroundRepository: BackgroundRepository {
    func backgrounds() async throws -> [ProjectionBackground] {
        Self.sample
    }

    static let sample = ProjectionBackground.gradients
}

extension ProjectionBackground {
    /// The six built-in gradients every church has.
    static let gradients: [ProjectionBackground] = [
        ProjectionBackground(id: "aurora", name: "Aurora", colors: [0x2A1658, 0x4E2A8C, 0x131E5C], isAnimated: true),
        ProjectionBackground(id: "brasa", name: "Brasa", colors: [0x3A1E08, 0x8C3A1E, 0x3D1235], isAnimated: false),
        ProjectionBackground(id: "oceano", name: "Océano", colors: [0x06283D, 0x0E5E6F, 0x0A1931], isAnimated: true),
        ProjectionBackground(id: "olivo", name: "Olivo", colors: [0x0F2417, 0x2F5233, 0x111A12], isAnimated: false),
        ProjectionBackground(id: "alba", name: "Alba", colors: [0x5B2A3C, 0xC0694E, 0x2B1A3A], isAnimated: false),
        ProjectionBackground(id: "medianoche", name: "Medianoche", colors: [0x07070B, 0x15151F, 0x07070B], isAnimated: false)
    ]
}
