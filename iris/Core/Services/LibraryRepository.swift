//
//  LibraryRepository.swift
//  iris
//

import Foundation

/// The church's content library: lyrics and the files uploaded on the web (Música, Multimedia, Fondos).
protocol LibraryRepository {
    func changes() -> AsyncStream<Void>
    func lyrics() async throws -> [LyricSheet]
    /// Files uploaded on the web, by kind (image, video, audio).
    func media(of kind: MediaAsset.Kind) async throws -> [MediaAsset]
    /// Starts downloading music or videos that were added to a service (contract §11); they stay on
    /// this iPad afterwards. Images and backgrounds download on their own after each sync.
    func download(_ ids: [MediaAsset.ID]) async
}

extension LibraryRepository {
    func changes() -> AsyncStream<Void> { .finished }

    func download(_ ids: [MediaAsset.ID]) async {}

    /// The Música section of the web: the church's tracks.
    func music() async -> [MediaAsset] {
        (try? await media(of: .music)) ?? []
    }

    /// The Multimedia section of the web: images and videos for presenting, without the ones
    /// that only serve as lyric backgrounds.
    func uploadedMedia() async -> [MediaAsset] {
        var all: [MediaAsset] = []
        for kind in [MediaAsset.Kind.image, .video] {
            all += ((try? await media(of: kind)) ?? []).filter { !$0.isBackground }
        }
        return all
    }
}
