//
//  LiveScreenView.swift
//  iris
//

import SwiftUI

/// Mirror of what the TV is showing right now.
struct LiveScreenView: View {
    let frame: ProjectionFrame
    var typography = ProjectionSettings()

    var body: some View {
        ProjectionCanvas(frame: frame, cornerRadius: IrisRadius.md, typography: typography)
            .overlay {
                RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)
                    .strokeBorder(IrisColor.strokeStrong)
            }
            .overlay(alignment: .topLeading) {
                IrisLiveIndicator(title: "EN VIVO")
                    .padding(IrisSpacing.xs)
            }
            .animation(IrisMotion.smooth, value: frame)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Pantalla en vivo"))
    }
}

/// Grid of backgrounds shown from the "change background" action.
struct BackgroundPickerView: View {
    let viewModel: LiveConsoleViewModel

    private let columns = Array(repeating: GridItem(.fixed(100), spacing: IrisSpacing.sm), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            IrisSectionHeader("FONDOS")

            LazyVGrid(columns: columns, spacing: IrisSpacing.md) {
                NoBackgroundSwatch(isSelected: viewModel.selectedBackgroundID == nil) {
                    withAnimation(IrisMotion.smooth) { viewModel.selectBackground(nil) }
                }
                ForEach(viewModel.backgrounds) { background in
                    BackgroundSwatch(
                        background: background,
                        isSelected: background.id == viewModel.selectedBackgroundID
                    ) {
                        withAnimation(IrisMotion.smooth) { viewModel.selectBackground(background.id) }
                    }
                }
            }
        }
        .padding(IrisSpacing.lg)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(IrisColor.canvasElevated)
    }
}

/// "Ninguno": pure black, chosen on purpose rather than left over by chance.
struct NoBackgroundSwatch: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: IrisSpacing.xs - 2) {
                RoundedRectangle(cornerRadius: IrisRadius.sm - 2, style: .continuous)
                    .fill(.black)
                    .frame(width: 92, height: 52)
                    .padding(3)
                    .overlay {
                        RoundedRectangle(cornerRadius: IrisRadius.sm + 1, style: .continuous)
                            .strokeBorder(isSelected ? IrisColor.textPrimary : .clear, lineWidth: 2)
                    }

                Text("Ninguno")
                    .font(IrisFont.caption)
                    .foregroundStyle(isSelected ? IrisColor.textPrimary : IrisColor.textTertiary)
            }
        }
        .buttonStyle(.irisPressable)
        .accessibilityLabel(Text("Ninguno: pantalla negra"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct BackgroundSwatch: View {
    let background: ProjectionBackground
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: IrisSpacing.xs - 2) {
                ProjectionBackgroundView(background: background)
                    .frame(width: 92, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: IrisRadius.sm - 2, style: .continuous))
                    .padding(3)
                    .overlay {
                        RoundedRectangle(cornerRadius: IrisRadius.sm + 1, style: .continuous)
                            .strokeBorder(isSelected ? IrisColor.textPrimary : .clear, lineWidth: 2)
                    }

                Text(background.name)
                    .font(IrisFont.caption)
                    .foregroundStyle(isSelected ? IrisColor.textPrimary : IrisColor.textTertiary)
            }
        }
        .buttonStyle(.irisPressable)
        .accessibilityLabel(Text(background.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
