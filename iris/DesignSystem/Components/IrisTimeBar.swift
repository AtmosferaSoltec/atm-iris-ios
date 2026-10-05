//
//  IrisTimeBar.swift
//  iris
//

import SwiftUI

/// Horizontal bar: track = planned, fill = actual (red when over), tick at planned.
struct IrisTimeBar: View {
    let planned: TimeInterval
    let actual: TimeInterval
    let scale: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let plannedX = width * planned / scale
            let actualX = width * actual / scale
            let isOver = actual > planned

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(IrisColor.surface)
                    .frame(width: plannedX)
                Capsule()
                    .fill(isOver ? AnyShapeStyle(IrisColor.danger) : AnyShapeStyle(IrisColor.success.opacity(0.85)))
                    .frame(width: actualX)
                Rectangle()
                    .fill(IrisColor.textPrimary.opacity(0.7))
                    .frame(width: 2, height: 16)
                    .offset(x: plannedX - 1)
            }
            .frame(height: proxy.size.height)
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}
