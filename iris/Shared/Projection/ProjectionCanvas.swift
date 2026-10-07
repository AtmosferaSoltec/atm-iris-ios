//
//  ProjectionCanvas.swift
//  iris
//

import AVFoundation
import SwiftUI

/// Renders a `ProjectionFrame` at any size with proportional typography,
/// so a thumbnail, the live preview and the TV look identical.
struct ProjectionCanvas: View {
    let frame: ProjectionFrame
    var cornerRadius: CGFloat = IrisRadius.sm
    /// Only the live preview should animate; thumbnails stay static for performance.
    var isAnimated = false
    /// How the lyrics look (contract §6); the same value everywhere draws a thumbnail, the live
    /// preview and the TV identically, exactly like `frame` itself.
    var typography = ProjectionSettings()

    @Environment(\.projectionVideoPlayer) private var videoPlayer

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                Color.black

                if let background = frame.background {
                    ProjectionBackgroundView(background: background)
                        .id(background.id)
                        .transition(.opacity)
                }

                // Identity per content makes slide changes cross-fade when animated.
                content(width: width)
                    .id(frame.content)
                    .transition(.opacity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        switch frame.content {
        case .blank:
            EmptyView()

        case let .text(body, footnote):
            VStack(spacing: width * 0.025) {
                Text(body)
                    .font(typography.bodyFont(width: width))
                    .lineSpacing(width * 0.006)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)

                if let footnote {
                    Text(footnote)
                        .font(typography.footnoteFont(width: width))
                        .tracking(width * 0.003)
                        .textCase(.uppercase)
                        .opacity(0.6)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: width * 0.012)
            .padding(width * 0.07)

        case .video where videoPlayer != nil:
            if let videoPlayer {
                PlayerLayerView(player: videoPlayer)
            }

        case let .video(title, duration, _):
            VStack(spacing: width * 0.03) {
                Image(systemName: "play.fill")
                    .font(.system(size: width * 0.05))
                    .frame(width: width * 0.13, height: width * 0.13)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: max(1, width * 0.002)))
                VStack(spacing: width * 0.008) {
                    Text(title)
                        .font(.system(size: width * 0.036, weight: .semibold, design: .serif))
                    Text(duration)
                        .font(.system(size: width * 0.022, weight: .medium).monospacedDigit())
                        .opacity(0.6)
                }
            }
            .foregroundStyle(.white)
            .padding(width * 0.07)

        case let .image(_, _, url?):
            // The real image, whole, over black.
            LocalImage(url: url, maxPixelSize: Self.imagePixelSize(width), contentMode: .fit)

        case let .image(_, artwork, nil):
            // Sample data: a gradient stands in for the image.
            LinearGradient(
                colors: artwork.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                RadialGradient(colors: [.white.opacity(0.18), .clear], center: .topLeading, startRadius: 0, endRadius: width * 0.8)
            }

        case let .audio(title, duration, _):
            VStack(spacing: width * 0.03) {
                Image(systemName: "waveform")
                    .font(.system(size: width * 0.07, weight: .semibold))
                    .foregroundStyle(IrisColor.success)
                VStack(spacing: width * 0.008) {
                    Text(title)
                        .font(.system(size: width * 0.036, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text(duration)
                        .font(.system(size: width * 0.022, weight: .medium).monospacedDigit())
                        .opacity(0.6)
                }
            }
            .foregroundStyle(.white)
            .padding(width * 0.07)

        case let .logo(name):
            VStack(spacing: width * 0.03) {
                IrisMark(size: width * 0.11)
                Text(name)
                    .font(.system(size: width * 0.04, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
            }

        case let .timer(text, isFinished):
            Text(text)
                .font(.system(size: width * (text.count > 5 ? 0.18 : 0.26), weight: .semibold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(isFinished ? IrisColor.danger : .white)
        }
    }
}

extension ProjectionCanvas {
    /// Decode images a bit larger than drawn (thumbnails stay small, the TV gets full resolution).
    static func imagePixelSize(_ width: CGFloat) -> CGFloat {
        min(3_840, max(320, width * 2))
    }
}

/// A projection background: one of the gradients, or a church image filling the screen.
struct ProjectionBackgroundView: View {
    let background: ProjectionBackground

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                gradient
                if let url = background.videoURL {
                    LoopingBackgroundVideo(url: url)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else if let url = background.imageURL {
                    LocalImage(url: url, maxPixelSize: ProjectionCanvas.imagePixelSize(proxy.size.width), contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            }
        }
        // Darken slightly so white text always clears contrast.
        .overlay(Color.black.opacity(0.2))
    }

    private var gradient: some View {
        LinearGradient(
            colors: background.colors.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [.white.opacity(0.14), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 600
            )
        }
    }
}

/// A background video: muted and looping forever, independent of whatever else is playing
/// (a background never has its own sound; the room's music comes from somewhere else).
private struct LoopingBackgroundVideo: View {
    let url: URL

    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        ZStack {
            if let player {
                PlayerLayerView(player: player, gravity: .resizeAspectFill)
            }
        }
        .onAppear {
            guard player == nil else { return }
            let queue = AVQueuePlayer()
            queue.isMuted = true
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
            queue.play()
            player = queue
        }
        .onDisappear {
            player?.pause()
            player = nil
            looper = nil
        }
    }
}

#Preview {
    let background = ProjectionBackground(id: "aurora", name: "Aurora", colors: [0x2A1658, 0x4E2A8C, 0x131E5C], isAnimated: true)
    VStack(spacing: 24) {
        ProjectionCanvas(frame: ProjectionFrame(background: background, content: .text("Jehová es mi pastor; nada me faltará.", footnote: "Salmos 23:1")))
        HStack(spacing: 24) {
            ProjectionCanvas(frame: ProjectionFrame(background: background, content: .video(title: "Testimonios", duration: "2:45")))
            ProjectionCanvas(frame: ProjectionFrame(background: background, content: .logo("Iglesia Vida Nueva")))
        }
    }
    .padding(48)
    .frame(width: 640)
    .background(IrisColor.canvas)
}
