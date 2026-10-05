//
//  MockMediaPlaybackService.swift
//  iris
//

import Foundation

/// Accepts every command silently; the console simulates elapsed time.
struct MockMediaPlaybackService: MediaPlaybackService {
    func play(itemID: ServiceItem.ID) {}
    func pause() {}
    func resume() {}
    func stop() {}
    func seek(to seconds: TimeInterval) {}
    func setLooping(_ isLooping: Bool) {}
}
