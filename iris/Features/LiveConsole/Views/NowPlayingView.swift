//
//  NowPlayingView.swift
//  iris
//

import SwiftUI

/// Compact transport for the music or video that is playing.
/// Lives under the live screen so it stays reachable while projecting lyrics.
struct NowPlayingView: View {
    let playback: LiveConsoleViewModel.Playback
    let onTogglePlay: () -> Void
    let onRestart: () -> Void
    let onStop: () -> Void
    let onToggleLoop: () -> Void
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
            header
            progress
            controls
        }
        .padding(.horizontal, IrisSpacing.xxs)
    }

    private var header: some View {
        HStack(spacing: IrisSpacing.sm) {
            Image(systemName: playback.kind.systemImage)
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(playback.kind.tint)
                .symbolEffect(.variableColor.iterative, isActive: playback.isPlaying)
                .frame(width: 32, height: 32)
                .background(playback.kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: IrisRadius.sm - 2, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(playback.title)
                    .font(IrisFont.calloutEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                    .lineLimit(1)
                Group {
                    if playback.isPlaying, playback.kind == .video {
                        Text("Reproduciendo en el TV")
                    } else if playback.isPlaying {
                        Text("Sonando en el salón")
                    } else {
                        Text("En pausa")
                    }
                }
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var progress: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(get: { playback.elapsed }, set: { onSeek($0) }),
                in: 0...max(playback.duration, 1)
            )
            .tint(IrisColor.coral)
            .accessibilityLabel(Text("Posición"))

            HStack {
                Text(Self.format(playback.elapsed))
                Spacer()
                Text("-\(Self.format(playback.duration - playback.elapsed))")
            }
            .font(.system(.caption2, design: .monospaced, weight: .medium))
            .foregroundStyle(IrisColor.textTertiary)
        }
    }

    private var controls: some View {
        HStack(spacing: IrisSpacing.sm) {
            Button(action: onRestart) {
                Image(systemName: "backward.end.fill")
            }
            .buttonStyle(.irisIcon)
            .accessibilityLabel(Text("Desde el inicio"))

            Spacer(minLength: 0)

            Button(action: onTogglePlay) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.irisIcon(isActive: true))
            .scaleEffect(1.15)
            .accessibilityLabel(playback.isPlaying ? Text("Pausar") : Text("Reproducir"))

            Button(action: onStop) {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.irisIcon)
            .accessibilityLabel(Text("Detener"))

            Spacer(minLength: 0)

            Button(action: onToggleLoop) {
                Image(systemName: "repeat")
            }
            .buttonStyle(.irisIcon(isActive: playback.isLooping))
            .accessibilityLabel(Text("Repetir"))
            .accessibilityAddTraits(playback.isLooping ? .isSelected : [])
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, seconds.rounded())).formatted(.time(pattern: .minuteSecond))
    }
}

/// Short-lived confirmation with an undo action.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: IrisSpacing.md) {
            Image(systemName: "trash")
                .foregroundStyle(IrisColor.textSecondary)
            Text(message)
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textPrimary)
                .lineLimit(1)
            Button("Deshacer", action: onUndo)
                .font(IrisFont.calloutEmphasized)
                .foregroundStyle(IrisColor.ember)
        }
        .padding(.horizontal, IrisSpacing.lg)
        .frame(height: 52)
        .glassEffect(.regular, in: .capsule)
    }
}
