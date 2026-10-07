//
//  ProjectionTypography.swift
//  iris
//
//  How the projected lyrics look (contract §6): same for every console of the church.
//

import Foundation

/// One of the 10 typefaces Iris offers for the projected lyrics. The raw value is the key the API
/// stores and syncs (`projection.fontFamily`); each platform translates it to its own real font
/// (`ProjectionFontFamily+Font.swift` has the iOS translation). Adding a typeface means adding a
/// case here and its translation on every platform — nothing else changes.
nonisolated enum ProjectionFontFamily: String, CaseIterable, Identifiable, Hashable, Sendable {
    case system, systemRounded, serif, georgia, avenirNext, futura, gillSans, optima, baskerville, palatino

    var id: Self { self }

    /// Shown in the picker; "(recomendada)" only on the default.
    var displayName: String {
        switch self {
        case .system: String(localized: "SF Pro (recomendada)")
        case .systemRounded: String(localized: "SF Pro Rounded")
        case .serif: String(localized: "New York (serif)")
        case .georgia: String(localized: "Georgia")
        case .avenirNext: String(localized: "Avenir Next")
        case .futura: String(localized: "Futura")
        case .gillSans: String(localized: "Gill Sans")
        case .optima: String(localized: "Optima")
        case .baskerville: String(localized: "Baskerville")
        case .palatino: String(localized: "Palatino")
        }
    }

    /// An unknown key (an older or newer server) falls back to the recommended one.
    init(apiValue: String) {
        self = Self(rawValue: apiValue) ?? .system
    }
}

/// Contract §6. `fontSizePt` is measured on a 1920-wide screen; every client scales it proportionally
/// to however big it is actually drawing (a thumbnail, the live preview, the TV).
nonisolated struct ProjectionSettings: Equatable, Sendable {
    static let fontSizeRange: ClosedRange<Int> = 40...200
    /// Sizes shown as quick picks; between them a stepper moves by 4.
    static let suggestedFontSizes = [56, 64, 72, 80, 88, 96, 112, 128, 144]

    var fontFamily: ProjectionFontFamily = .system
    var fontSizePt: Int = 88
    /// A gradient or an uploaded image (`ProjectionBackground.id`); `nil` shows black.
    var defaultBackgroundId: String?
}
