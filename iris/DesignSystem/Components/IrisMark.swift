//
//  IrisMark.swift
//  iris
//

import SwiftUI

/// The Iris brand mark: an open spectrum ring with a glint. Static everywhere;
/// only the splash animates its two layers (see `IrisSplashView`).
struct IrisMark: View {
    var size: CGFloat = 32
    /// Ring rotation, used by the splash. The glint never turns.
    var ringRotation: Angle = .zero
    var glintOpacity: Double = 1

    var body: some View {
        ZStack {
            Image(.irisRing)
                .resizable()
                .rotationEffect(ringRotation)
            Image(.irisGlint)
                .resizable()
                .opacity(glintOpacity)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Mark + logotype, from the vector logo asset (text is outlined, so it needs no font).
struct IrisWordmark: View {
    /// Height of the mark; the logotype scales with it.
    var markSize: CGFloat = 30

    var body: some View {
        Image(.irisLogo)
            .resizable()
            .scaledToFit()
            .frame(height: markSize)
            .accessibilityLabel(Text(verbatim: "Iris"))
    }
}

#Preview {
    VStack(spacing: 48) {
        IrisMark(size: 160)
        IrisWordmark()
    }
    .padding(64)
    .background(IrisColor.canvas)
}
