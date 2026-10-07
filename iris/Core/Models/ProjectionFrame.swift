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
    /// A church video marked as background: muted, looping, drawn to fill the screen (contract §11).
    var videoURL: URL?

    init(id: String, name: String, colors: [UInt32], isAnimated: Bool, imageURL: URL? = nil, videoURL: URL? = nil) {
        self.id = id
        self.name = name
        self.colors = colors
        self.isAnimated = isAnimated
        self.imageURL = imageURL
        self.videoURL = videoURL
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
        /// The countdown: big digits over the background. `isFinished` turns them red.
        case timer(text: String, isFinished: Bool)
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
