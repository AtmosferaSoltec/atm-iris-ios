//
//  LibraryRepository.swift
//  iris
//

import Foundation

/// The church's content library: lyrics and media files.
protocol LibraryRepository {
    func changes() -> AsyncStream<Void>
    func lyrics() async throws -> [LyricSheet]
    func media(of kind: MediaAsset.Kind) async throws -> [MediaAsset]
}

extension LibraryRepository {
    func changes() -> AsyncStream<Void> { .finished }
}
