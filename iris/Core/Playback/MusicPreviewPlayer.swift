//
//  MusicPreviewPlayer.swift
//  iris
//
//  A quick listen to a song from the library: the first seconds, in the foreground, one at a time.
//  Not the service player: it has no queue, no background audio and never touches the TV.
//

import AVFoundation
import Observation

@Observable
@MainActor
final class MusicPreviewPlayer {
    /// How much of the song plays before it stops by itself.
    static let previewSeconds: Double = 12

    /// The file being previewed, if any.
    private(set) var playingURL: URL?

    private var player: AVAudioPlayer?
    private var stopTask: Task<Void, Never>?

    func isPlaying(_ url: URL) -> Bool { playingURL == url }

    /// Starts the preview, or stops it when that same song is already playing.
    func toggle(_ url: URL) {
        if playingURL == url {
            stop()
        } else {
            start(url)
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        player?.stop()
        player = nil
        playingURL = nil
    }

    // MARK: Private

    private func start(_ url: URL) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            guard player.play() else { return }
            self.player = player
            playingURL = url
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.previewSeconds))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            // A file the player cannot open just does not play: there is nothing to fix from here.
            playingURL = nil
        }
    }
}
