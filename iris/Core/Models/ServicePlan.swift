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

    init(id: UUID = UUID(), kind: Kind, title: String, subtitle: String, slides: [Slide]) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.slides = slides
    }
}

/// A single projectable unit within a service item.
nonisolated struct Slide: Identifiable, Hashable, Sendable {
    enum Content: Hashable, Sendable {
        case text(String, footnote: String?)
        case image(title: String, artwork: [UInt32])
        case video(title: String, duration: String)
        /// Audio plays in the room; nothing changes on the TV.
        case audio(title: String, duration: String)
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
