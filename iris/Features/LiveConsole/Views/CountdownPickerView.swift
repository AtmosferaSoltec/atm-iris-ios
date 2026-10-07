//
//  CountdownPickerView.swift
//  iris
//

import SwiftUI

/// The "Temporizador" flyout: pick a duration, or control the countdown while it runs.
/// While it counts it takes the TV (big digits over the background) unless the screen is
/// cleared or the operator hides it; the lyrics come back when it stops. It makes no sound.
struct CountdownPickerView: View {
    @Bindable var viewModel: LiveConsoleViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: IrisSpacing.sm), count: 4)

    var body: some View {
        VStack(spacing: IrisSpacing.md) {
            IrisSectionHeader("TEMPORIZADOR")

            if viewModel.countdown.isIdle {
                idle
            } else {
                active
            }
        }
        .padding(IrisSpacing.lg)
        .frame(width: 300)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(IrisColor.canvasElevated)
    }

    private var idle: some View {
        VStack(spacing: IrisSpacing.md) {
            LazyVGrid(columns: columns, spacing: IrisSpacing.sm) {
                ForEach(LiveConsoleViewModel.countdownPresets, id: \.self) { minutes in
                    Button("\(minutes) min") {
                        viewModel.startCountdown(minutes: minutes)
                    }
                    .buttonStyle(.irisPill)
                }
            }

            HStack(spacing: IrisSpacing.sm) {
                Stepper(value: $viewModel.customCountdownMinutes, in: 1...Double(CountdownTimer.maxMinutes)) {
                    Text("\(Int(viewModel.customCountdownMinutes)) min")
                        .font(IrisFont.callout)
                        .foregroundStyle(IrisColor.textPrimary)
                }
                Button("Iniciar") {
                    viewModel.startCustomCountdown()
                }
                .buttonStyle(.irisPrimary)
            }
        }
    }

    private var active: some View {
        VStack(spacing: IrisSpacing.sm) {
            Text(viewModel.countdownStatusText)
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.textSecondary)

            Text(viewModel.countdownRemainingText)
                .font(.system(size: 44, weight: .semibold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(viewModel.countdown.isFinished ? IrisColor.danger : IrisColor.textPrimary)
                .contentTransition(.numericText())
                .animation(IrisMotion.snappy, value: viewModel.countdownRemainingText)

            HStack(spacing: IrisSpacing.sm) {
                Button(viewModel.countdownPauseButtonText) {
                    viewModel.toggleCountdownPause()
                }
                .buttonStyle(.irisPill)
                .disabled(!viewModel.canPauseCountdown)

                Button("+1 min") {
                    viewModel.addCountdownMinute()
                }
                .buttonStyle(.irisPill)

                Button("Detener", role: .destructive) {
                    viewModel.stopCountdown()
                }
                .buttonStyle(.irisPill)
            }

            Button(viewModel.countdownTvButtonText) {
                viewModel.toggleCountdownTv()
            }
            .buttonStyle(.irisLink)
        }
    }
}

#Preview("Inactivo") {
    CountdownPickerView(viewModel: .preview)
        .preferredColorScheme(.dark)
}

#Preview("Contando") {
    let viewModel = LiveConsoleViewModel.preview
    viewModel.startCountdown(minutes: 10)
    return CountdownPickerView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
