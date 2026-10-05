//
//  IrisLandscapeCanvas.swift
//  iris
//

import SwiftUI

/// Keeps Iris's landscape design intact in any window shape.
///
/// Iris is designed only for landscape. iPadOS 27 no longer lets an app lock its orientation
/// (`UIRequiresFullScreen` is deprecated, see TN3192), so when the window is smaller than the
/// landscape canvas — the iPad turned to portrait, or a narrow window — the whole interface is
/// laid out at canvas size and scaled down proportionally. Nothing reflows or deforms, and the
/// console is never blocked mid-service.
struct IrisLandscapeCanvas<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        // GeometryReader takes the window's safe area as is, independent of the content.
        GeometryReader { proxy in
            let available = proxy.size
            let scale = Self.scale(toFit: available)
            let isScaled = scale < 1
            let canvas = isScaled ? Self.canvasSize(for: available, scale: scale) : available

            // The modifiers are always applied (as no-ops at full size) so the content keeps
            // its identity — and its state — when the window crosses the canvas size.
            content
                // The scaled canvas sits inside the window's safe area already; inside it,
                // screens lay out without insets.
                .ignoresSafeArea(isScaled ? .all : [])
                .frame(width: canvas.width, height: canvas.height)
                .scaleEffect(scale)
                .frame(width: canvas.width * scale, height: canvas.height * scale)
                .frame(width: available.width, height: available.height)
        }
        // Fills the safe-area margins around a scaled canvas with the same backdrop.
        .background { IrisBackground(isAnimated: false) }
    }

    /// 1 when the canvas fits; otherwise the factor that shrinks it into `size`.
    static func scale(toFit size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        let canvas = IrisSize.landscapeCanvas
        let scale = min(size.width / canvas.width, size.height / canvas.height)
        return scale < 1 ? scale : 1
    }

    /// Size the content is laid out at before scaling: fills the window but never gets
    /// taller than a landscape screen, so a portrait window shows the landscape design
    /// centered instead of stretched. A portrait window flipped (width ÷ height) gives the
    /// device's own landscape proportions; 4:3 caps any other shape.
    static func canvasSize(for available: CGSize, scale: CGFloat) -> CGSize {
        let width = available.width / scale
        let maxAspect = min(IrisSize.landscapeCanvasMaxAspect, available.width / available.height)
        let height = min(available.height / scale, width * maxAspect)
        return CGSize(width: width, height: height)
    }
}

#Preview("Retrato: el diseño horizontal escalado", traits: .portrait) {
    IrisLandscapeCanvas {
        VStack(spacing: IrisSpacing.md) {
            Text("Lienzo horizontal")
                .font(IrisFont.title)
            Text("1100 pt de ancho como mínimo")
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .border(IrisColor.coral)
    }
    .preferredColorScheme(.dark)
}
