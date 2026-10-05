//
//  MediaPlaybackService.swift
//  iris
//

import Foundation

/// Plays music in the room and video on the TV. V1 mocks it; a real
/// implementation will wrap AVPlayer. Timing state lives in the console.
protocol MediaPlaybackService {
    func play(itemID: ServiceItem.ID)
    func pause()
    func resume()
    func stop()
    func seek(to seconds: TimeInterval)
    func setLooping(_ isLooping: Bool)
}
