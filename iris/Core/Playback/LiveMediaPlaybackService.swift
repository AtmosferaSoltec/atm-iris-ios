//
//  LiveMediaPlaybackService.swift
//  iris
//

import AVFoundation
import MediaPlayer
import os

/// Real playback with `AVPlayer`. Music sounds in the room (also with the silent switch and the screen
/// locked); a video shares its player with `ProjectionStore` so the TV and the console's preview show it.
final class LiveMediaPlaybackService: MediaPlaybackService {
    private let projection: ProjectionStore
    private var player: AVPlayer?
    private var itemID: ServiceItem.ID?
    private var title = ""
    private var isLooping = false
    private var timeObserver: Any?
    private var endObserver: (any NSObjectProtocol)?
    private var subscribers: [UUID: AsyncStream<PlaybackProgress>.Continuation] = [:]
    private var hasRemoteCommands = false

    private static let logger = Logger(subsystem: "com.atmosfera.iris", category: "playback")

    init(projection: ProjectionStore = .shared) {
        self.projection = projection
    }

    let reportsProgress = true

    func progressUpdates() -> AsyncStream<PlaybackProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: PlaybackProgress.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.subscribers[id] = nil }
        }
        return stream
    }

    func play(itemID: ServiceItem.ID, url: URL?, kind: ServiceItem.Kind, title: String) {
        stop()
        guard let url else { return }
        activateAudioSession()
        let player = AVPlayer(url: url)
        self.player = player
        self.itemID = itemID
        self.title = title
        if kind == .video { projection.videoPlayer = player }

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.report() }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: player.currentItem, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.didReachEnd() }
        }
        setUpRemoteCommands()
        player.play()
        report()
    }

    func pause() {
        player?.pause()
        report()
    }

    func resume() {
        player?.play()
        report()
    }

    func stop() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        player?.pause()
        if projection.videoPlayer === player { projection.videoPlayer = nil }
        player = nil
        itemID = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to seconds: TimeInterval) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        report()
    }

    func setLooping(_ isLooping: Bool) {
        self.isLooping = isLooping
    }

    // MARK: Private

    private var elapsed: TimeInterval {
        player.map { CMTimeGetSeconds($0.currentTime()) }.flatMap { $0.isFinite ? $0 : nil } ?? 0
    }

    private var duration: TimeInterval {
        player?.currentItem.map { CMTimeGetSeconds($0.duration) }.flatMap { $0.isFinite ? $0 : nil } ?? 0
    }

    private var isPlaying: Bool { (player?.rate ?? 0) > 0 }

    private func report(didFinish: Bool = false) {
        guard let itemID else { return }
        let progress = PlaybackProgress(itemID: itemID, elapsed: elapsed, duration: duration, isPlaying: isPlaying, didFinish: didFinish)
        for continuation in subscribers.values { continuation.yield(progress) }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlaybackDuration: progress.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress.elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: progress.isPlaying ? 1.0 : 0.0
        ]
    }

    /// End of file: start over when looping, otherwise tell the console it finished.
    private func didReachEnd() {
        if isLooping {
            player?.seek(to: .zero)
            player?.play()
            report()
        } else {
            report(didFinish: true)
            stop()
        }
    }

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            Self.logger.error("No se pudo activar el audio: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Play and pause from the lock screen and Control Center.
    private func setUpRemoteCommands() {
        guard !hasRemoteCommands else { return }
        hasRemoteCommands = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isPlaying ? self.pause() : self.resume()
            }
            return .success
        }
    }
}
