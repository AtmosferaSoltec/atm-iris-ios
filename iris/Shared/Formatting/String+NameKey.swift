//
//  String+NameKey.swift
//  iris
//

import Foundation

nonisolated extension String {
    /// Trimmed, case- and accent-insensitive form used to compare names: " José " matches "jose".
    var nameKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
    }
}
