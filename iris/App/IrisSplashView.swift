//
//  IrisSplashView.swift
//  iris
//

import SwiftUI

/// Launch splash: the ring spins into place, the glint lights up, then the splash
/// fades away. The only place the logo animates.
struct IrisSplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringRotation = Angle.degrees(-160)
    @State private var ringScale = 0.82
    @State private var ringOpacity = 0.0
    @State private var glintOpacity = 0.0

    var body: some View {
        ZStack {
            IrisColor.canvas.ignoresSafeArea()

            IrisMark(size: 160, ringRotation: ringRotation, glintOpacity: glintOpacity)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
        }
        .task {
            if reduceMotion {
                ringRotation = .zero
                ringScale = 1
                withAnimation(.easeOut(duration: 0.4)) {
                    ringOpacity = 1
                    glintOpacity = 1
                }
            } else {
                withAnimation(.spring(duration: 1.1, bounce: 0.15)) {
                    ringRotation = .zero
                    ringScale = 1
                    ringOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.35).delay(0.75)) {
                    glintOpacity = 1
                }
            }
            try? await Task.sleep(for: .seconds(1.6))
            onFinished()
        }
    }
}

#Preview {
    IrisSplashView {}
}
