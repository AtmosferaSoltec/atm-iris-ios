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
    var copyright: String?
    var sections: [Slide]

    init(id: UUID = UUID(), title: String, author: String, copyright: String? = nil, sections: [Slide]) {
        self.id = id
        self.title = title
        self.author = author
        self.copyright = copyright
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

    /// Whether the file is on this iPad.
    enum DownloadState: Hashable, Sendable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed
    }

    let id: String
    var kind: Kind
    var title: String
    /// Artist, album or short description.
    var subtitle: String
    /// "3:45". `nil` for images.
    var duration: String?
    /// Placeholder colors, drawn when there is no file (sample data) or while it loads.
    var artwork: [UInt32]
    /// The cached file, once downloaded.
    var localURL: URL? = nil
    var downloadState: DownloadState = .ready
    var durationSeconds: Double? = nil
    var width: Int? = nil
    var height: Int? = nil
    /// Images only: offered in the background picker.
    var isBackground = false

    /// Only downloaded files can be added to a service, so they project without network.
    var isAvailable: Bool { downloadState == .ready }
}
