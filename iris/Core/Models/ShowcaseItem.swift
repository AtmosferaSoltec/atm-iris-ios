//
//  ShowcaseItem.swift
//  iris
//

import Foundation

/// A sample of projected content (lyric or verse) used for previews.
nonisolated struct ShowcaseItem: Identifiable, Equatable, Sendable {
    enum Kind: Sendable {
        case lyric, verse
    }

    let id: UUID
    let kind: Kind
    let text: String
    let reference: String

    init(id: UUID = UUID(), kind: Kind, text: String, reference: String) {
        self.id = id
        self.kind = kind
        self.text = text
        self.reference = reference
    }
}
