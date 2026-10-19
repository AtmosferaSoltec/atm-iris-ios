//
//  Library.swift
//  iris
//

import Foundation

/// A song in the church library (contract §10): the lyrics shown on the TV and the track played
/// in the room, together. It has lyrics, a track or both.
nonisolated struct LyricSheet: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var author: String
    var copyright: String?
    /// Empty when the song is only a track.
    var sections: [Slide]
    /// The track, with its download state on this iPad; `nil` when the song is only lyrics.
    var audio: MediaAsset?

    init(id: UUID = UUID(), title: String, author: String, copyright: String? = nil, sections: [Slide], audio: MediaAsset? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.copyright = copyright
        self.sections = sections
        self.audio = audio
    }

    /// No lyrics: it only plays, the TV stays as it is.
    var isTrackOnly: Bool { sections.isEmpty && audio != nil }

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

    /// The file is on this iPad: it can play or go to the TV. Music and videos can be added to a
    /// service before that; adding them starts the download.
    var isAvailable: Bool { downloadState == .ready }
}
