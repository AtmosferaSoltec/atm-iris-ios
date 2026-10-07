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
    /// The library file behind music, image and video items, so the console can follow its
    /// download and pick up the file once it is on this iPad. `nil` for text and sample data.
    var mediaID: String?
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
        planItemID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.slides = slides
        self.songID = songID
        self.mediaID = mediaID
        self.planItemID = planItemID
    }
}

/// Which library item a plan row points at (contract §15).
nonisolated enum PlanItemKind: Sendable {
    case song, media
}

nonisolated extension ServiceItem {
    /// Builds a song item from the library, with a stable reference back to it.
    init(lyric: LyricSheet) {
        self.init(kind: .song, title: lyric.title, subtitle: lyric.author, slides: lyric.sections, songID: lyric.id)
    }

    /// Builds a music, image or video item from the library, with a stable reference back to it.
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
