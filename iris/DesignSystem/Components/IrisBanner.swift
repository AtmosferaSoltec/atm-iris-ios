//
//  IrisBanner.swift
//  iris
//

import SwiftUI

/// Inline feedback message.
struct IrisBanner: View {
    enum Style {
        case error, success, info

        var tint: Color {
            switch self {
            case .error: IrisColor.danger
            case .success: IrisColor.success
            case .info: IrisColor.textSecondary
            }
        }

        var icon: String {
            switch self {
            case .error: "exclamationmark.triangle.fill"
            case .success: "checkmark.circle.fill"
            case .info: "info.circle.fill"
            }
        }
    }

    let style: Style
    let message: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)

        HStack(alignment: .firstTextBaseline, spacing: IrisSpacing.sm) {
            Image(systemName: style.icon)
                .foregroundStyle(style.tint)
            Text(message)
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, IrisSpacing.md)
        .padding(.vertical, IrisSpacing.sm + 2)
        .background(style.tint.opacity(0.12), in: shape)
        .overlay(shape.strokeBorder(style.tint.opacity(0.35)))
    }
}
