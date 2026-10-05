//
//  ProjectionPreview.swift
//  iris
//

import SwiftUI

/// A miniature of the TV output, showing how content reads on the big screen.
struct ProjectionPreview: View {
    let item: ShowcaseItem?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.lg, style: .continuous)

        ZStack {
            shape.fill(.black)

            RadialGradient(
                colors: [IrisColor.glowViolet, .black],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
            .clipShape(shape)

            if let item {
                VStack(spacing: IrisSpacing.md) {
                    Text(item.text)
                        .font(IrisFont.projection)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .minimumScaleFactor(0.6)

                    Text(item.reference)
                        .font(IrisFont.caption)
                        .tracking(IrisTracking.caps)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, IrisSpacing.xl)
                .padding(.vertical, IrisSpacing.xxl)
                .id(item.id)
                .transition(.blurReplace)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            IrisLiveIndicator()
                .padding(IrisSpacing.sm + 2)
        }
        .overlay { shape.strokeBorder(.white.opacity(0.12)) }
        .shadow(color: IrisColor.violet.opacity(0.3), radius: 60, y: 30)
        .animation(IrisMotion.gentle, value: item)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ProjectionPreview(item: MockShowcaseContentProvider().items()[1])
        .frame(width: 440)
        .padding(64)
        .background(IrisColor.canvas)
}
