//
//  IrisLiveIndicator.swift
//  iris
//

import SwiftUI

/// Pulsing red dot that marks live content.
struct IrisLiveDot: View {
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(IrisColor.live)
            .frame(width: size, height: size)
            .phaseAnimator([false, true]) { dot, isDimmed in
                dot
                    .opacity(isDimmed ? 0.3 : 1)
                    .scaleEffect(isDimmed ? 0.8 : 1)
            } animation: { _ in
                .easeInOut(duration: 0.9)
            }
            .accessibilityHidden(true)
    }
}

/// Pulsing "on screen" badge, used wherever content is being projected.
struct IrisLiveIndicator: View {
    var title: LocalizedStringKey = "EN PANTALLA"

    var body: some View {
        HStack(spacing: IrisSpacing.xs - 2) {
            IrisLiveDot()

            Text(title)
                .font(IrisFont.overline)
                .tracking(IrisTracking.caps)
                .foregroundStyle(IrisColor.textPrimary)
        }
        .padding(.horizontal, IrisSpacing.sm - 2)
        .padding(.vertical, IrisSpacing.xs - 2)
        .glassEffect(.regular, in: .capsule)
    }
}
