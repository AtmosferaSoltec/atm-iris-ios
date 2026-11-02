//
//  ToolsSheet.swift
//  iris
//

import SwiftUI

/// The tools that live next to the screen: a countdown to show and the sound effects.
struct ToolsSheet: View {
    enum Tool: String, Hashable, Identifiable, CaseIterable {
        case clock, sounds
        var id: String { rawValue }
    }

    let client: RemoteClient
    let state: RemoteState

    @State private var tool: Tool = .clock

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            SheetHeader("Herramientas") { EmptyView() }

            IrisSegmentedControl(options: Tool.allCases, selection: $tool) { tool in
                switch tool {
                case .clock: LocalizedStringResource("Cronómetro")
                case .sounds: LocalizedStringResource("Sonidos")
                }
            }
            .frame(maxWidth: 360)

            switch tool {
            case .clock: ClockTool(client: client, countdown: state.countdown)
            case .sounds: SoundsTool(client: client, sounds: state.sounds)
            }
            Spacer(minLength: 0)
        }
        .padding(IrisSpacing.lg)
        .frame(minWidth: 640, minHeight: 440)
    }
}

/// The countdown shown on the projection screen: it is the computer's, started and paused from here.
private struct ClockTool: View {
    let client: RemoteClient
    let countdown: RemoteState.Countdown?

    @State private var minutes = 5
    /// Shown with the countdown on the screens, like the computer's «Texto (opcional)».
    @State private var label = ""

    var body: some View {
        VStack(spacing: IrisSpacing.lg) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = countdown.map { client.remaining(of: $0, at: context.date) } ?? Double(minutes * 60)
                Text(seconds.clock)
                    .font(.system(size: 88, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, IrisSpacing.lg)
                    .background(.black, in: RoundedRectangle(cornerRadius: IrisRadius.md))
            }

            if countdown == nil {
                TextField("Texto (opcional), ej. Empezamos en…", text: $label)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
                    .onChange(of: label) { _, value in if value.count > 60 { label = String(value.prefix(60)) } }
                HStack(spacing: IrisSpacing.sm) {
                    ForEach([1, 3, 5, 10, 15], id: \.self) { value in
                        Button { minutes = value } label: {
                            Text("\(value) min").padding(.horizontal, IrisSpacing.md)
                        }
                        .buttonStyle(.irisGlass)
                        .fixedSize()
                        .overlay(Capsule().strokeBorder(minutes == value ? IrisColor.coral : .clear, lineWidth: 2))
                        .opacity(minutes == value ? 1 : 0.7)
                    }
                }
            } else if let text = countdown?.label, !text.isEmpty {
                Text(text).font(IrisFont.callout).foregroundStyle(IrisColor.textSecondary)
            }

            HStack(spacing: IrisSpacing.sm) {
                if let countdown {
                    Button {
                        client.send(.countdown(countdown.isRunning ? .pause : .resume))
                    } label: {
                        Label(countdown.isRunning ? "Pausar" : "Reanudar", systemImage: countdown.isRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.irisPrimary)
                    Button { client.send(.countdown(.hide)) } label: { Label("Ocultar", systemImage: "eye.slash") }
                        .buttonStyle(.irisGlass)
                } else {
                    Button {
                        let text = label.trimmingCharacters(in: .whitespaces)
                        client.send(.countdown(.start, seconds: minutes * 60, label: text.isEmpty ? nil : text))
                    } label: {
                        Label("Iniciar en la pantalla", systemImage: "play.fill")
                    }
                    .buttonStyle(.irisPrimary)
                }
            }
        }
    }
}

/// Short sound effects played from the computer.
private struct SoundsTool: View {
    let client: RemoteClient
    let sounds: [RemoteSound]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: IrisSpacing.sm), count: 4)
    @State private var lastPlayed: String?

    var body: some View {
        if sounds.isEmpty {
            Text("No hay sonidos en la computadora. Agrégalos en Iris, en Herramientas → Sonidos.")
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: IrisSpacing.sm) {
                    ForEach(sounds) { sound in
                        Button {
                            lastPlayed = sound.id
                            client.send(.playSound(id: sound.id))
                        } label: {
                            VStack(spacing: IrisSpacing.xs) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.title)
                                    .foregroundStyle(lastPlayed == sound.id ? IrisColor.coral : IrisColor.textPrimary)
                                Text(sound.title).font(IrisFont.caption).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 96)
                            .background(IrisColor.surface, in: RoundedRectangle(cornerRadius: IrisRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: IrisRadius.md)
                                    .strokeBorder(lastPlayed == sound.id ? IrisColor.coral : IrisColor.stroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.irisPressable)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
