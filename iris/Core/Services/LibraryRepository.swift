//
//  LibraryRepository.swift
//  iris
//

import Foundation

/// The church's content library: lyrics, the files uploaded on the web and the songs stored on this iPad.
protocol LibraryRepository {
    func changes() -> AsyncStream<Void>
    func lyrics() async throws -> [LyricSheet]
    /// Files uploaded on the web, by kind (image, video, audio).
    func media(of kind: MediaAsset.Kind) async throws -> [MediaAsset]
    /// Songs in the "Música" folder of this iPad. Never uploaded: only this device reads them.
    func localMusic() async -> [MediaAsset]
}

extension LibraryRepository {
    func changes() -> AsyncStream<Void> { .finished }

    /// Everything uploaded on the web for presenting (images, videos and audio), without the
    /// images and videos that only serve as lyric backgrounds.
    func uploadedMedia() async -> [MediaAsset] {
        var all: [MediaAsset] = []
        for kind in [MediaAsset.Kind.image, .video, .music] {
            all += ((try? await media(of: kind)) ?? []).filter { !$0.isBackground }
        }
        return all
    }
}
