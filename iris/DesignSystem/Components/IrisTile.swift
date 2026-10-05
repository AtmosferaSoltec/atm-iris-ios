//
//  IrisTile.swift
//  iris
//

import SwiftUI

/// Tappable dashboard card: tinted icon, title, subtitle, free content and a chevron.
struct IrisTile<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: String?
    let systemImage: String
    let tint: Color
    let action: () -> Void
    let content: Content

    init(
        _ title: LocalizedStringKey,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            IrisSurface(padding: IrisSpacing.lg, cornerRadius: IrisRadius.xl) {
                VStack(alignment: .leading, spacing: IrisSpacing.lg) {
                    header
                    content
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(.irisPressable)
    }

    private var header: some View {
        HStack(spacing: IrisSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IrisFont.bodyEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(IrisFont.caption)
                        .foregroundStyle(IrisColor.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(IrisColor.textTertiary)
        }
    }
}

extension IrisTile where Content == EmptyView {
    /// Header-only tile: icon, title, subtitle and chevron.
    init(
        _ title: LocalizedStringKey,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void = {}
    ) {
        self.init(title, subtitle: subtitle, systemImage: systemImage, tint: tint, action: action) { EmptyView() }
    }
}
