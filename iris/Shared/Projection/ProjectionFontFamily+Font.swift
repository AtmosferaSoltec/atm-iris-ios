//
//  ProjectionFontFamily+Font.swift
//  iris
//
//  Translates a `ProjectionFontFamily` key into the real iOS font. The other platforms do the same
//  translation with their own fonts (see the table in `docs/api-contract.md` §6); the key is what
//  travels over the wire, never a font name.
//

import SwiftUI

extension ProjectionFontFamily {
    /// The PostScript name UIKit ships for this family, picked for the weight the lyrics screen
    /// uses. `nil` for the three system designs, drawn with `Font.system` instead.
    fileprivate var postScriptName: String? {
        switch self {
        case .system, .systemRounded, .serif: nil
        case .georgia: "Georgia"
        case .avenirNext: "AvenirNext-Medium"
        case .futura: "Futura-Medium"
        case .gillSans: "GillSans"
        case .optima: "Optima-Regular"
        case .baskerville: "Baskerville"
        case .palatino: "Palatino-Roman"
        }
    }

    /// `weight` only reaches `Font.system`: a custom named font has one weight (its own), SwiftUI
    /// cannot reliably synthesize another from a PostScript name.
    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .system: return Font.system(size: size, weight: weight)
        case .systemRounded: return Font.system(size: size, weight: weight, design: .rounded)
        case .serif: return Font.system(size: size, weight: weight, design: .serif)
        default:
            guard let postScriptName else { return Font.system(size: size, weight: weight) }
            return Font.custom(postScriptName, size: size)
        }
    }
}

extension ProjectionSettings {
    /// The projected text's font at a canvas of this width; `width / 1920` scales `fontSizePt` down
    /// for a thumbnail or up for a 4K TV, so every surface shows the same relative size.
    func bodyFont(width: CGFloat) -> Font {
        fontFamily.font(size: width / 1920 * CGFloat(fontSizePt), weight: .medium)
    }

    /// Same ratio the fixed sizes had (footnote 0.022 of width, body 0.046): kept exactly so a
    /// church that never opens Proyección sees no change at all.
    func footnoteFont(width: CGFloat) -> Font {
        fontFamily.font(size: width / 1920 * CGFloat(fontSizePt) * (0.022 / 0.046), weight: .semibold)
    }
}
