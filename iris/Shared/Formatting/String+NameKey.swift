//
//  String+NameKey.swift
//  iris
//

import Foundation

nonisolated extension String {
    /// Form used to compare names (API contract §2): trimmed, inner spaces collapsed to one,
    /// without diacritics and lowercased. "  José   Pérez " → "jose perez".
    var nameKey: String {
        split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            .lowercased()
    }
}
