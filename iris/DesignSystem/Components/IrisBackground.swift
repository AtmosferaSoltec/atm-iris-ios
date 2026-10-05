//
//  IrisBackground.swift
//  iris
//

import SwiftUI

/// Slow, breathing mesh of colored light over the dark canvas.
/// Freezes automatically when Reduce Motion is enabled.
struct IrisBackground: View {
    /// Pass `false` behind dense working screens to keep attention on content.
    var isAnimated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let colors: [Color] = [
        IrisColor.glowViolet, IrisColor.canvas, IrisColor.glowIndigo,
        IrisColor.canvas, IrisColor.canvas, IrisColor.canvas,
        IrisColor.glowRose, IrisColor.glowEmber, IrisColor.canvas
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isAnimated || reduceMotion)) { context in
            MeshGradient(
                width: 3,
                height: 3,
                points: points(at: context.date.timeIntervalSinceReferenceDate),
                colors: colors
            )
        }
        .overlay {
            // Vignette keeps the edges deep and the focus on the content.
            RadialGradient(
                colors: [.clear, IrisColor.canvas.opacity(0.7)],
                center: .center,
                startRadius: 240,
                endRadius: 1_000
            )
        }
        .background(IrisColor.canvas)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// Drifts the inner mesh vertices on slow, out-of-phase sine waves.
    private func points(at time: TimeInterval) -> [SIMD2<Float>] {
        let a = Float(sin(time * 0.21))
        let b = Float(cos(time * 0.17))
        let c = Float(sin(time * 0.13 + 1.3))
        return [
            [0, 0], [0.5 + 0.12 * a, 0], [1, 0],
            [0, 0.5 + 0.1 * b], [0.5 + 0.14 * b, 0.5 + 0.12 * c], [1, 0.5 - 0.1 * a],
            [0, 1], [0.5 - 0.12 * c, 1], [1, 1]
        ]
    }
}

#Preview {
    IrisBackground()
}
