//
//  IrisCheckmark.swift
//  iris
//

import SwiftUI

/// Round selection indicator for multi-select lists and grids.
struct IrisCheckmark: View {
    let isOn: Bool
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            if isOn {
                Circle()
                    .fill(IrisGradient.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.48, weight: .bold))
                    .foregroundStyle(IrisColor.textInverse)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .strokeBorder(IrisColor.strokeStrong, lineWidth: 1.5)
                    .background(Circle().fill(.black.opacity(0.25)))
            }
        }
        .frame(width: size, height: size)
        .animation(IrisMotion.snappy, value: isOn)
        .accessibilityHidden(true)
    }
}
