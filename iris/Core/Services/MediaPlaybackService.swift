//
//  MediaPlaybackService.swift
//  iris
//

import Foundation

/// Real playback position, reported by the live service.
nonisolated struct PlaybackProgress: Equatable, Sendable {
    let itemID: ServiceItem.ID
    let elapsed: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    /// The file ended without looping.
    var didFinish = false
}

/// Plays music in the room and video on the TV. One playback at a time.
protocol MediaPlaybackService {
    /// `url` is the cached file; `kind` is `.music` or `.video`.
    func play(itemID: ServiceItem.ID, url: URL?, kind: ServiceItem.Kind, title: String)
    func pause()
    func resume()
    func stop()
    func seek(to seconds: TimeInterval)
    func setLooping(_ isLooping: Bool)
    /// `true` when elapsed time comes from real playback; otherwise the console simulates it.
    var reportsProgress: Bool { get }
    /// Position updates every half second, until the consuming task ends.
    func progressUpdates() -> AsyncStream<PlaybackProgress>
}

extension MediaPlaybackService {
    var reportsProgress: Bool { false }
    func progressUpdates() -> AsyncStream<PlaybackProgress> { AsyncStream { $0.finish() } }
}
