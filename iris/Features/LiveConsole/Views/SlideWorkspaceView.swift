//
//  SlideWorkspaceView.swift
//  iris
//

import SwiftUI

/// Right column: every slide of the open item (song or Bible passage).
/// Tapping a slide sends it to the TV.
struct SlideWorkspaceView: View {
    @Bindable var viewModel: LiveConsoleViewModel

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: IrisSpacing.md)]

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            header

            if let item = viewModel.selectedItem, viewModel.isShowingMedia, let slide = item.slides.first {
                MediaStageView(
                    kind: item.kind,
                    frame: viewModel.cardFrame(for: slide),
                    typography: viewModel.typography,
                    isActive: viewModel.isSelectedMediaActive,
                    download: viewModel.selectedMediaDownload,
                    onRetry: { viewModel.retrySelectedMediaDownload() }
                ) {
                    withAnimation(IrisMotion.smooth) { viewModel.presentSelectedMedia() }
                }
                .id(item.id)
                .transition(.opacity)
            } else if let item = viewModel.selectedItem {
                slideGrid(for: item)
            } else {
                ContentUnavailableView("Selecciona un elemento", systemImage: "rectangle.stack")
                    .foregroundStyle(IrisColor.textSecondary)
            }
        }
        .sheet(item: $viewModel.biblePicker) { picker in
            BiblePickerView(viewModel: picker)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: IrisSpacing.md) {
            itemTitle
            Spacer(minLength: 0)
            toolbar
        }
    }

    @ViewBuilder
    private var itemTitle: some View {
        if let item = viewModel.selectedItem {
            VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                IrisChip(item.kind.displayName, systemImage: item.kind.systemImage, tint: item.kind.tint)
                Text(item.title)
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                Text(item.subtitle)
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }
            .id(item.id)
            .transition(.opacity)
        }
    }

    private var toolbar: some View {
        HStack(spacing: IrisSpacing.xs) {
            if viewModel.isShowingScripture {
                Button {
                    withAnimation(IrisMotion.smooth) { viewModel.previous() }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.irisIcon)
                .disabled(!viewModel.canGoPrevious)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .accessibilityLabel(Text("Versículo anterior"))

                Button {
                    withAnimation(IrisMotion.smooth) { viewModel.next() }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.irisIcon)
                .disabled(!viewModel.canGoNext)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .accessibilityLabel(Text("Versículo siguiente"))

                Divider()
                    .frame(height: 28)
                    .padding(.horizontal, IrisSpacing.xxs)
            }

            Button {
                withAnimation(IrisMotion.smooth) { viewModel.toggleClearScreen() }
            } label: {
                Image(systemName: "eraser")
            }
            .buttonStyle(.irisIcon(isActive: viewModel.isScreenCleared))
            .accessibilityLabel(Text("Limpiar pantalla"))
            .accessibilityAddTraits(viewModel.isScreenCleared ? .isSelected : [])

            Button {
                viewModel.presentBackgroundPicker()
            } label: {
                Image(systemName: "photo.on.rectangle")
            }
            .buttonStyle(.irisIcon)
            .accessibilityLabel(Text("Cambiar fondo"))
            .popover(isPresented: $viewModel.isPickingBackground) {
                BackgroundPickerView(viewModel: viewModel)
            }

            if viewModel.showsBible {
                Button {
                    viewModel.presentBible()
                } label: {
                    Image(systemName: "book.closed")
                }
                .buttonStyle(.irisIcon)
                .accessibilityLabel(Text("Biblia"))
            }

            Button {
                viewModel.presentCountdownPicker()
            } label: {
                Label(viewModel.countdownButtonText, systemImage: "timer")
            }
            .buttonStyle(.irisPill)
            .accessibilityLabel(Text("Temporizador"))
            .popover(isPresented: $viewModel.isPickingCountdown) {
                CountdownPickerView(viewModel: viewModel)
            }

            if !viewModel.isShowingScripture {
                Button {} label: {
                    Label("Editar", systemImage: "pencil")
                }
                .buttonStyle(.irisPill)
                .padding(.leading, IrisSpacing.xxs)
            }
        }
    }

    // MARK: Grid

    private func slideGrid(for item: ServiceItem) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: IrisSpacing.lg) {
                    ForEach(Array(item.slides.enumerated()), id: \.element.id) { index, slide in
                        SlideCard(
                            frame: viewModel.cardFrame(for: slide),
                            typography: viewModel.typography,
                            label: slide.label,
                            isSelected: viewModel.isLive(slideIndex: index)
                        ) {
                            withAnimation(IrisMotion.smooth) { viewModel.goLive(slideIndex: index) }
                        }
                    }
                }
                .padding(IrisSpacing.xxs)
            }
            .scrollIndicators(.hidden)
            // Keep the slide on the TV in view (e.g. verse 16 of a long chapter).
            .onChange(of: viewModel.liveSlideID, initial: true) { _, id in
                guard let id else { return }
                withAnimation(IrisMotion.smooth) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

/// Black card with white text. Only the slide on the TV is highlighted.
/// The label underneath is optional — not every slide has one.
struct SlideCard: View {
    let frame: ProjectionFrame
    var typography = ProjectionSettings()
    let label: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous)

        Button(action: action) {
            VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                ProjectionCanvas(frame: frame, typography: typography)
                    .overlay {
                        shape.strokeBorder(
                            isSelected ? AnyShapeStyle(IrisGradient.accent) : AnyShapeStyle(IrisColor.stroke),
                            lineWidth: isSelected ? 3 : 1
                        )
                    }
                    .shadow(color: isSelected ? IrisColor.coral.opacity(0.3) : .clear, radius: 16, y: 4)

                if let label {
                    Text(label)
                        .font(IrisFont.label)
                        .foregroundStyle(isSelected ? IrisColor.textPrimary : IrisColor.textSecondary)
                        .padding(.horizontal, IrisSpacing.xxs)
                }
            }
        }
        .buttonStyle(.irisPressable)
        .accessibilityLabel(label.map { Text($0) } ?? Text("Diapositiva"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("Envía esta diapositiva al TV"))
    }
}
