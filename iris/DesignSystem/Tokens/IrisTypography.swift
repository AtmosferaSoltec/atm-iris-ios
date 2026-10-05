//
//  IrisTypography.swift
//  iris
//

import SwiftUI

/// Type scale. Editorial serif (New York) for display moments and projected
/// content; SF Pro for interface text. Interface styles scale with Dynamic Type.
enum IrisFont {
    // MARK: Editorial (serif)

    static let display = Font.system(size: 56, weight: .medium, design: .serif)
    static let headline = Font.system(.largeTitle, design: .serif, weight: .medium)
    static let title = Font.system(.title, design: .serif, weight: .medium)
    /// Lyrics and verses as previewed inside the console.
    static let projection = Font.system(size: 26, weight: .regular, design: .serif)

    // MARK: Interface (sans)

    static let subtitle = Font.system(.title3)
    static let body = Font.system(.body)
    static let bodyEmphasized = Font.system(.body, weight: .semibold)
    static let callout = Font.system(.callout)
    static let calloutEmphasized = Font.system(.callout, weight: .semibold)
    static let label = Font.system(.footnote, weight: .medium)
    static let caption = Font.system(.caption, weight: .medium)
    /// Small uppercase labels. Pair with `IrisTracking.overline`.
    static let overline = Font.system(.caption2, weight: .bold)
}

/// Letter-spacing tokens.
enum IrisTracking {
    static let tight: CGFloat = -0.5
    static let overline: CGFloat = 2.0
    static let caps: CGFloat = 1.2
}
