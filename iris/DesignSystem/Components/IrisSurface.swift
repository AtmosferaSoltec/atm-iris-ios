//
//  IrisSurface.swift
//  iris
//

import SwiftUI

/// Frosted, elevated container for content panels (forms, editors, lists).
/// Liquid Glass is reserved for controls that float above content.
struct IrisSurface<Content: View>: View {
    var padding: CGFloat = IrisSpacing.xl
    var cornerRadius: CGFloat = IrisRadius.xxl
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .background {
                shape.fill(.ultraThinMaterial)
                shape.fill(IrisColor.canvasElevated.opacity(0.72))
            }
            .overlay {
                // Top-lit hairline gives the panel a physical edge.
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .white.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(0.45), radius: 40, y: 24)
    }
}
