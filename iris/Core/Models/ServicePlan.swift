//
//  ServicePlan.swift
//  iris
//

import Foundation

/// An ordered run sheet for a church service.
nonisolated struct ServicePlan: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var date: Date
    var items: [ServiceItem]
}

/// One element of the service order: a song, a passage, an announcement or media.
nonisolated struct ServiceItem: Identifiable, Equatable, Sendable {
    enum Kind: Sendable {
        case song, scripture, announcement, music, image, video
    }

    let id: UUID
    var kind: Kind
    var title: String
    /// Author, reference or short description.
    var subtitle: String
    var slides: [Slide]
    /// The song behind a `.song` item, so it can be adelantado and found again in the plan
    /// (contract §15). `nil` for text typed by hand and sample data.
    var songID: UUID?
    /// The library file behind music, image and video items — and a song's track — so the console
    /// can follow its download and pick up the file once it is on this iPad. `nil` for text and
    /// sample data.
    var mediaID: String?
    /// The track of a song that also has lyrics: it plays in the room while the slides go to the
    /// TV. A song that is only a track is a `.music` item instead.
    var track: ServiceTrack?
    /// The row in the service plan this item came from (or was saved to), so moving or removing
    /// it here also updates it there. `nil` for items never adelantados: the Bible and the logo,
    /// which stay only for the length of this service.
    var planItemID: UUID?

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        subtitle: String,
        slides: [Slide],
        songID: UUID? = nil,
        mediaID: String? = nil,
        track: ServiceTrack? = nil,
        planItemID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.slides = slides
        self.songID = songID
        self.mediaID = mediaID
        self.track = track
        self.planItemID = planItemID
    }
}

/// A song's track inside the service (contract §10): ready to play, never automatically.
nonisolated struct ServiceTrack: Equatable, Sendable {
    var title: String
    /// "3:45", or empty when unknown.
    var duration: String
    /// The cached file; `nil` while it is not on this iPad (or in sample data).
    var url: URL?
}

/// Which library item a plan row points at (contract §15).
nonisolated enum PlanItemKind: Sendable {
    case song, media
}

nonisolated extension ServiceItem {
    /// Builds a song item from the library, with a stable reference back to it. Its track comes
    /// along: a song with lyrics carries it as `track`; a song that is only a track plays like music.
    init(lyric: LyricSheet) {
        guard let audio = lyric.audio else {
            self.init(kind: .song, title: lyric.title, subtitle: lyric.author, slides: lyric.sections, songID: lyric.id)
            return
        }
        let duration = audio.duration ?? ""
        let subtitle = [lyric.author, duration].filter { !$0.isEmpty }.joined(separator: " · ")
        if lyric.sections.isEmpty {
            self.init(
                kind: .music,
                title: lyric.title,
                subtitle: subtitle,
                slides: [Slide(content: .audio(title: lyric.title, duration: duration, url: audio.localURL))],
                songID: lyric.id,
                mediaID: audio.id
            )
        } else {
            self.init(
                kind: .song,
                title: lyric.title,
                subtitle: subtitle,
                slides: lyric.sections,
                songID: lyric.id,
                mediaID: audio.id,
                track: ServiceTrack(title: lyric.title, duration: duration, url: audio.localURL)
            )
        }
    }

    /// Builds an image or video item from the library, with a stable reference back to it. (Audio
    /// only reaches the service inside its song, `init(lyric:)`.)
    init(asset: MediaAsset) {
        switch asset.kind {
        case .music:
            self.init(
                kind: .music,
                title: asset.title,
                subtitle: "\(asset.subtitle) · \(asset.duration ?? "")",
                slides: [Slide(content: .audio(title: asset.title, duration: asset.duration ?? "", url: asset.localURL))],
                mediaID: asset.id
            )
        case .image:
            self.init(
                kind: .image,
                title: asset.title,
                subtitle: asset.subtitle,
                slides: [Slide(content: .image(title: asset.title, artwork: asset.artwork, url: asset.localURL))],
                mediaID: asset.id
            )
        case .video:
            self.init(
                kind: .video,
                title: asset.title,
                subtitle: String(localized: "Video · \(asset.duration ?? "")"),
                slides: [Slide(content: .video(title: asset.title, duration: asset.duration ?? "", url: asset.localURL))],
                mediaID: asset.id
            )
        }
    }

    /// The cached file behind the item: its track, or its media slide. `nil` for text or while the
    /// file is not on this iPad.
    var fileURL: URL? {
        track?.url ?? slides.first?.content.url
    }

    /// `(kind, refID)` for the service plan (contract §15); `nil` for an item never adelantado
    /// (the Bible, the logo) that only lasts for this service.
    var planReference: (kind: PlanItemKind, refID: String)? {
        if let songID { return (.song, songID.apiString) }
        if let mediaID { return (.media, mediaID) }
        return nil
    }
}

/// A single projectable unit within a service item.
nonisolated struct Slide: Identifiable, Hashable, Sendable {
    enum Content: Hashable, Sendable {
        case text(String, footnote: String?)
        /// `url` is the cached file; `nil` in sample data, which draws `artwork` instead.
        case image(title: String, artwork: [UInt32], url: URL? = nil)
        case video(title: String, duration: String, url: URL? = nil)
        /// Audio plays in the room; nothing changes on the TV.
        case audio(title: String, duration: String, url: URL? = nil)
    }

    let id: UUID
    /// Optional section label, e.g. "Estrofa 1", "Coro", "v. 3".
    var label: String?
    var content: Content

    init(id: UUID = UUID(), label: String? = nil, content: Content) {
        self.id = id
        self.label = label
        self.content = content
    }
}

nonisolated extension Slide.Content {
    /// The cached file of a media slide; `nil` for text or while it is not on this iPad.
    var url: URL? {
        switch self {
        case .text: nil
        case let .image(_, _, url), let .video(_, _, url), let .audio(_, _, url): url
        }
    }

    /// The same media with another cached file (or none). Text stays as it is.
    func replacingURL(_ url: URL?) -> Self {
        switch self {
        case .text: self
        case let .image(title, artwork, _): .image(title: title, artwork: artwork, url: url)
        case let .video(title, duration, _): .video(title: title, duration: duration, url: url)
        case let .audio(title, duration, _): .audio(title: title, duration: duration, url: url)
        }
    }
}
