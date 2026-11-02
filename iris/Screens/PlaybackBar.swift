//
//  PlaybackBar.swift
//  iris
//

import SwiftUI

/// The computer's audio and video controls, at the bottom: position, play/pause, stop, repeat and volume.
struct PlaybackBar: View {
    let client: RemoteClient
    let state: RemoteState
    /// The element open; the bar plays it when nothing is playing yet.
    let item: RemoteItem?

    /// While the finger is on the slider, the bar follows it instead of the computer.
    @State private var dragPosition: Double?
    @State private var dragVolume: Double?

    private var playback: RemoteState.Playback? { state.playback }
    private var isPlaying: Bool { playback?.isPlaying ?? false }
    private var duration: Double { max(playback?.duration ?? 0, 1) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = dragPosition ?? playback.map { client.position(of: $0, at: context.date) } ?? 0
            HStack(spacing: IrisSpacing.lg) {
                titleBlock
                HStack(spacing: IrisSpacing.sm) {
                    Text(position.clock).font(.system(.caption, design: .monospaced))
                    Slider(
                        value: Binding(get: { position }, set: { dragPosition = $0 }),
                        in: 0...duration
                    ) { isEditing in
                        if !isEditing, let target = dragPosition {
                            client.send(.seek(seconds: target))
                            dragPosition = nil
                        }
                    }
                    .tint(IrisColor.coral)
                    .disabled(playback == nil)
                    Text(playback == nil ? "0:00" : "-\(max(duration - position, 0).clock)").font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(IrisColor.textSecondary)
                transport
                volume
                clearButton
            }
        }
        .padding(.horizontal, IrisSpacing.md)
        .padding(.vertical, IrisSpacing.sm)
        .background(IrisColor.canvasElevated.opacity(0.72), in: RoundedRectangle(cornerRadius: IrisRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: IrisRadius.lg).strokeBorder(IrisColor.stroke, lineWidth: 1))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(playback?.title ?? item?.title ?? "Nada en reproducción").font(IrisFont.calloutEmphasized).lineLimit(1)
            if playback?.hasError == true {
                Text("No se pudo reproducir")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.danger)
            } else {
                Text(playback.map { $0.kind == .video ? "Video" : "Pista" } ?? (item?.isPlayable == true ? "Lista para reproducir" : "Sin audio"))
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textSecondary)
            }
        }
        .frame(width: 150, alignment: .leading)
    }

    private var transport: some View {
        HStack(spacing: IrisSpacing.sm) {
            Button { client.send(.playback(.restart)) } label: { Image(systemName: "backward.end.fill") }
                .buttonStyle(.irisIcon)
                .disabled(playback == nil)
                .accessibilityLabel("Desde el inicio")
            Button { client.send(.playback(isPlaying ? .pause : .play)) } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(IrisColor.textInverse)
                    .frame(width: 48, height: 48)
                    .background(IrisColor.coral, in: Circle())
            }
            .buttonStyle(.irisPressable)
            .disabled(playback == nil && item?.isPlayable != true)
            .opacity(playback == nil && item?.isPlayable != true ? 0.4 : 1)
            .accessibilityLabel(isPlaying ? "Pausar" : "Reproducir")
            Button { client.send(.playback(.stop)) } label: { Image(systemName: "stop.fill") }
                .buttonStyle(.irisIcon)
                .disabled(playback == nil)
                .accessibilityLabel("Detener")
            Button { client.send(.playback(playback?.isLooping == true ? .loopOff : .loopOn)) } label: {
                Image(systemName: "repeat")
            }
            .buttonStyle(.irisIcon(isActive: playback?.isLooping == true))
            .disabled(playback == nil)
            .accessibilityLabel("Repetir")
        }
    }

    private var volume: some View {
        let value = dragVolume ?? state.volume
        return HStack(spacing: IrisSpacing.xs) {
            Image(systemName: value == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .foregroundStyle(IrisColor.textSecondary)
            Slider(value: Binding(get: { value }, set: { dragVolume = $0 })) { isEditing in
                if !isEditing, let target = dragVolume {
                    client.send(.volume(target))
                    dragVolume = nil
                }
            }
            .tint(IrisColor.textSecondary)
            .frame(width: 110)
        }
    }

    private var clearButton: some View {
        Button {
            client.send(.setCleared(!state.isCleared))
        } label: {
            Label(state.isCleared ? "Mostrar" : "Limpiar", systemImage: state.isCleared ? "eye" : "eraser")
                .padding(.horizontal, IrisSpacing.xs)
        }
        .buttonStyle(.irisGlass)
        .fixedSize()
    }
}
