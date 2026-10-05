//
//  ProjectionFrame.swift
//  iris
//

import Foundation

/// A background layer for projected content.
nonisolated struct ProjectionBackground: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    /// Gradient stops as 24-bit hex values. Placeholder until real image/video assets exist.
    var colors: [UInt32]
    var isAnimated: Bool
}

/// Everything the TV needs to render one moment of output.
/// The console thumbnails, the live preview and the external display all render this same value.
nonisolated struct ProjectionFrame: Equatable, Sendable {
    enum Content: Hashable, Sendable {
        case blank
        case text(String, footnote: String?)
        case image(title: String, artwork: [UInt32])
        case video(title: String, duration: String)
        case audio(title: String, duration: String)
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
