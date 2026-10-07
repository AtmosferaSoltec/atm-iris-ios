//
//  ProjectionSettingsView.swift
//  iris
//

import SwiftUI

/// Typeface, size and default background of the projected lyrics, with a live preview.
struct ProjectionSettingsView: View {
    @Bindable var viewModel: ProjectionSettingsViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            header

            if viewModel.isLoading {
                ProgressView()
                    .tint(IrisColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: IrisSpacing.xl) {
                        if let errorMessage = viewModel.errorMessage {
                            IrisBanner(style: .error, message: errorMessage)
                        }
                        if !viewModel.canManage {
                            IrisBanner(style: .info, message: String(localized: "Solo un administrador puede cambiar esto."))
                        }
                        preview
                        fontSection
                        sizeSection
                        backgroundSection
                    }
                    .disabled(!viewModel.canManage)
                    .padding(.bottom, IrisSpacing.xxl)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(IrisSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationSizing(.form)
        .presentationBackground(IrisColor.canvasElevated)
        .task { await viewModel.load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Proyección")
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                Text("La tipografía, el tamaño y el fondo por defecto de la letra en el TV.")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.irisIcon)
                .accessibilityLabel(Text("Cerrar"))
        }
    }

    // MARK: Preview

    private var preview: some View {
        ProjectionCanvas(frame: viewModel.previewFrame, cornerRadius: IrisRadius.lg, typography: viewModel.settings)
            .overlay {
                RoundedRectangle(cornerRadius: IrisRadius.lg, style: .continuous)
                    .strokeBorder(IrisColor.strokeStrong)
            }
            .accessibilityLabel(Text("Vista previa de cómo se ve la letra en el TV"))
    }

    // MARK: Font

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
            IrisSectionHeader("TIPOGRAFÍA")

            VStack(spacing: 0) {
                ForEach(ProjectionFontFamily.allCases) { family in
                    if family != ProjectionFontFamily.allCases.first {
                        Divider().overlay(IrisColor.stroke)
                    }
                    Button {
                        viewModel.selectFontFamily(family)
                    } label: {
                        HStack {
                            Text(family.displayName)
                                .font(IrisFont.callout)
                                .foregroundStyle(IrisColor.textPrimary)
                            Spacer()
                            if family == viewModel.settings.fontFamily {
                                Image(systemName: "checkmark")
                                    .font(.system(.callout, weight: .semibold))
                                    .foregroundStyle(IrisGradient.accent)
                            }
                        }
                        .padding(.vertical, IrisSpacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, IrisSpacing.md)
            .background(IrisColor.surface, in: RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous))
        }
    }

    // MARK: Size

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
            IrisSectionHeader("TAMAÑO") {
                Text("\(viewModel.settings.fontSizePt) pt")
                    .monospacedDigit()
            }

            HStack(spacing: IrisSpacing.md) {
                IconButton(systemImage: "minus", label: "Reducir tamaño") { viewModel.decreaseFontSize() }
                    .disabled(!viewModel.canDecreaseFontSize)

                HStack(spacing: IrisSpacing.xs) {
                    ForEach(ProjectionSettings.suggestedFontSizes, id: \.self) { size in
                        Button {
                            viewModel.setFontSize(size)
                        } label: {
                            Text("\(size)")
                                .font(.system(.footnote, weight: .semibold).monospacedDigit())
                                .frame(minWidth: 36)
                                .padding(.vertical, IrisSpacing.xs)
                                .background(
                                    size == viewModel.settings.fontSizePt
                                        ? AnyShapeStyle(IrisGradient.accent) : AnyShapeStyle(IrisColor.surface),
                                    in: Capsule()
                                )
                                .foregroundStyle(size == viewModel.settings.fontSizePt ? IrisColor.canvas : IrisColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)

                IconButton(systemImage: "plus", label: "Aumentar tamaño") { viewModel.increaseFontSize() }
                    .disabled(!viewModel.canIncreaseFontSize)
            }

            Text("El tamaño se mide en una pantalla de 1920 de ancho; en una más grande o más chica se ve proporcional.")
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.textTertiary)
        }
    }

    // MARK: Default background

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
            IrisSectionHeader("FONDO AL INICIAR UN SERVICIO")

            Text("Lo que se ve en el TV hasta que pones una letra. «Ninguno» es pantalla negra.")
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.textTertiary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: IrisSpacing.sm)], spacing: IrisSpacing.sm) {
                NoBackgroundSwatch(isSelected: viewModel.settings.defaultBackgroundId == nil) {
                    viewModel.selectDefaultBackground(nil)
                }
                ForEach(viewModel.backgrounds) { background in
                    BackgroundSwatch(
                        background: background,
                        isSelected: background.id == viewModel.settings.defaultBackgroundId
                    ) {
                        viewModel.selectDefaultBackground(background.id)
                    }
                }
            }
        }
    }
}

/// Round icon button used for the font-size stepper.
private struct IconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.callout, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(IrisColor.surface, in: Circle())
                .foregroundStyle(IrisColor.textPrimary)
        }
        .buttonStyle(.irisPressable)
        .accessibilityLabel(Text(label))
    }
}

#Preview {
    ProjectionSettingsView(
        viewModel: {
            let viewModel = ProjectionSettingsViewModel(
                repository: MockProjectionSettingsRepository(store: InMemoryChurchStore()),
                backgroundRepository: MockBackgroundRepository()
            )
            viewModel.apply(settings: ProjectionSettings(), backgrounds: MockBackgroundRepository.sample)
            return viewModel
        }()
    )
    .frame(width: 520, height: 820)
    .background(IrisColor.canvasElevated)
    .preferredColorScheme(.dark)
}
