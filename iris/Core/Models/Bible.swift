//
//  Bible.swift
//  iris
//

import Foundation

nonisolated struct BibleBook: Identifiable, Hashable, Sendable {
    enum Testament: Hashable, Sendable, CaseIterable {
        case old, new
    }

    let id: String
    let name: String
    let testament: Testament
    let chapterCount: Int
}

nonisolated struct BibleVerse: Identifiable, Hashable, Sendable {
    var id: Int { number }
    let number: Int
    let text: String
}
