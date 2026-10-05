//
//  IrisColor.swift
//  iris
//

import SwiftUI

/// Color tokens. Iris is dark-first: the console lives in dim sanctuaries
/// and must never compete with the content shown on the big screen.
enum IrisColor {
    // MARK: Canvas & surfaces

    static let canvas = Color(hex: 0x07070B)
    static let canvasElevated = Color(hex: 0x0E0E15)
    static let surface = Color.white.opacity(0.05)
    static let surfaceRaised = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.09)
    static let strokeStrong = Color.white.opacity(0.18)

    // MARK: Text

    static let textPrimary = Color(hex: 0xF6F3EE)
    static let textSecondary = Color(hex: 0xF6F3EE).opacity(0.64)
    static let textTertiary = Color(hex: 0xF6F3EE).opacity(0.40)
    /// Text placed on light or accent fills.
    static let textInverse = Color(hex: 0x120D0A)

    // MARK: Spectrum — light passing through stained glass

    static let ember = Color(hex: 0xFFB547)
    static let coral = Color(hex: 0xFF7A59)
    static let rose = Color(hex: 0xF0508C)
    static let violet = Color(hex: 0x9B5CFF)
    static let indigo = Color(hex: 0x4E5BFF)

    static let accent = coral

    // MARK: Ambient glows (used by animated backgrounds)

    static let glowViolet = Color(hex: 0x2A1658)
    static let glowIndigo = Color(hex: 0x131E5C)
    static let glowRose = Color(hex: 0x3D1235)
    static let glowEmber = Color(hex: 0x3A1E08)

    // MARK: Semantic

    static let success = Color(hex: 0x3DDC97)
    static let warning = Color(hex: 0xFFC857)
    static let danger = Color(hex: 0xFF5C7A)
    static let live = Color(hex: 0xFF3B5C)
}

/// Gradient tokens built from the spectrum.
enum IrisGradient {
    static let spectrum: [Color] = [
        IrisColor.ember, IrisColor.coral, IrisColor.rose, IrisColor.violet, IrisColor.indigo
    ]

    /// Warm accent used for primary actions and highlights.
    static let accent = LinearGradient(
        colors: [IrisColor.ember, IrisColor.coral, IrisColor.rose],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Color {
    /// Creates a color from a 24-bit hex value, e.g. `0xFF7A59`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
