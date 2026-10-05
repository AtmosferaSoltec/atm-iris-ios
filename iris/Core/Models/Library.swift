//
//  Library.swift
//  iris
//

import Foundation

/// Song lyrics stored in the church library.
nonisolated struct LyricSheet: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var author: String
    var sections: [Slide]

    init(id: UUID = UUID(), title: String, author: String, sections: [Slide]) {
        self.id = id
        self.title = title
        self.author = author
        self.sections = sections
    }

    /// First line of the first text section, used as a preview.
    var firstLine: String? {
        guard case let .text(text, _) = sections.first?.content else { return nil }
        return text.split(separator: "\n").first.map(String.init)
    }
}

/// A music, image or video file in the church library.
nonisolated struct MediaAsset: Identifiable, Hashable, Sendable {
    enum Kind: Sendable {
        case music, image, video
    }

    let id: String
    var kind: Kind
    var title: String
    /// Artist, album or short description.
    var subtitle: String
    /// "3:45". `nil` for images.
    var duration: String?
    /// Placeholder artwork colors until real thumbnails exist.
    var artwork: [UInt32]
}
