//
//  ProjectionFrame.swift
//  iris
//

import Foundation

/// A background layer for projected content.
nonisolated struct ProjectionBackground: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    /// Gradient stops as 24-bit hex values. Also the placeholder while an image background loads.
    var colors: [UInt32]
    var isAnimated: Bool
    /// A church image marked as background, drawn to fill the screen.
    var imageURL: URL?

    init(id: String, name: String, colors: [UInt32], isAnimated: Bool, imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.colors = colors
        self.isAnimated = isAnimated
        self.imageURL = imageURL
    }
}

/// Everything the TV needs to render one moment of output.
/// The console thumbnails, the live preview and the external display all render this same value.
nonisolated struct ProjectionFrame: Equatable, Sendable {
    enum Content: Hashable, Sendable {
        case blank
        case text(String, footnote: String?)
        /// `url` is the cached file; `nil` draws the `artwork` placeholder.
        case image(title: String, artwork: [UInt32], url: URL? = nil)
        case video(title: String, duration: String, url: URL? = nil)
        case audio(title: String, duration: String, url: URL? = nil)
        case logo(String)
    }

    /// `nil` renders pure black.
    var background: ProjectionBackground?
    var content: Content

    static let black = ProjectionFrame(background: nil, content: .blank)
}

/// A connected external screen.
nonisolated struct ExternalDisplay: Equatable, Sendable {
    var name: String
    var resolution: String
}
