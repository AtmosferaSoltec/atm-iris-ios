//
//  IrisChip.swift
//  iris
//

import SwiftUI

/// Compact tinted tag for kinds and statuses.
struct IrisChip: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var tint: Color = IrisColor.textSecondary

    init(_ title: LocalizedStringKey, systemImage: String? = nil, tint: Color = IrisColor.textSecondary) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: IrisSpacing.xxs + 1) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(.caption2, weight: .bold))
            }
            Text(title)
                .font(IrisFont.caption)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, IrisSpacing.xs + 2)
        .padding(.vertical, IrisSpacing.xxs + 1)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.25)))
    }
}

/// Uppercase section title with an optional trailing accessory.
struct IrisSectionHeader<Accessory: View>: View {
    let title: LocalizedStringKey
    let accessory: Accessory

    init(_ title: LocalizedStringKey, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(IrisFont.overline)
                .tracking(IrisTracking.overline)
                .foregroundStyle(IrisColor.textTertiary)
            Spacer(minLength: IrisSpacing.xs)
            accessory
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.textTertiary)
        }
    }
}

extension IrisSectionHeader where Accessory == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.title = title
        self.accessory = EmptyView()
    }
}
