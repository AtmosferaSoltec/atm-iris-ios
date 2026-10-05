//
//  MediaThumbnail.swift
//  iris
//

import SwiftUI

/// Thumbnail of a cached file: the image itself, downsampled, or the first frame of a video.
struct MediaThumbnail: View {
    let url: URL
    let kind: MediaAsset.Kind

    @State private var frameURL: URL?

    var body: some View {
        switch kind {
        case .image:
            LocalImage(url: url, maxPixelSize: 480)
        case .video:
            ZStack {
                if let frameURL {
                    LocalImage(url: frameURL, maxPixelSize: 480)
                }
            }
            .task(id: url) { frameURL = await VideoThumbnailer.shared.thumbnail(for: url) }
        case .music:
            EmptyView()
        }
    }
}
