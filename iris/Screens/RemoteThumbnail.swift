//
//  RemoteThumbnail.swift
//  iris
//

import SwiftUI

/// The computer's still of an image or a video, filling its frame; nothing (the frame's own fill) until it arrives
/// or when there is none. A video never plays here.
struct RemoteThumbnail: View {
    let client: RemoteClient
    let id: String?

    var body: some View {
        Color.clear
            .overlay {
                if let id, let image = client.thumbnails[id] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            .animation(IrisMotion.smooth, value: id.flatMap { client.thumbnails[$0] } != nil)
            .task(id: id) { if let id { client.wantThumbnail(id) } }
    }
}

/// The film badge on a video's picture, so a still is never mistaken for an image.
struct VideoBadge: View {
    var seconds: Double?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "film")
            if let seconds { Text(seconds.clock).monospacedDigit() }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.black.opacity(0.65), in: Capsule())
        .padding(IrisSpacing.xs)
    }
}
