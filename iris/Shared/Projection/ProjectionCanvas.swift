//
//  ProjectionCanvas.swift
//  iris
//

import SwiftUI

/// Renders a `ProjectionFrame` at any size with proportional typography,
/// so a thumbnail, the live preview and the TV look identical.
struct ProjectionCanvas: View {
    let frame: ProjectionFrame
    var cornerRadius: CGFloat = IrisRadius.sm
    /// Only the live preview should animate; thumbnails stay static for performance.
    var isAnimated = false

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
                    .font(.system(size: width * 0.046, weight: .medium, design: .serif))
                    .lineSpacing(width * 0.006)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)

                if let footnote {
                    Text(footnote)
                        .font(.system(size: width * 0.022, weight: .semibold))
                        .tracking(width * 0.003)
                        .textCase(.uppercase)
                        .opacity(0.6)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: width * 0.012)
            .padding(width * 0.07)

        case let .video(title, duration):
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

        case let .image(_, artwork):
            // Full-bleed image. Gradient placeholder until real assets exist.
            LinearGradient(
                colors: artwork.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                RadialGradient(colors: [.white.opacity(0.18), .clear], center: .topLeading, startRadius: 0, endRadius: width * 0.8)
            }

        case let .audio(title, duration):
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
        }
    }
}

/// Gradient placeholder for a projection background.
struct ProjectionBackgroundView: View {
    let background: ProjectionBackground

    var body: some View {
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
        // Darken slightly so white text always clears contrast.
        .overlay(Color.black.opacity(0.2))
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
