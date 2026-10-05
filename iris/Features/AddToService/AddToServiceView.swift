//
//  AddToServiceView.swift
//  iris
//

import SwiftUI

/// Library browser with four tabs: Letras · Música · Imágenes · Videos.
/// Items can be picked across tabs and are appended to the service in pick order.
struct AddToServiceView: View {
    @Bindable var viewModel: AddToServiceViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    private enum Field: Hashable { case search }

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            header

            if !viewModel.isLyricsOnly {
                IrisSegmentedControl(
                    options: viewModel.tabs,
                    selection: $viewModel.tab,
                    title: \.title
                )
            }

            IrisTextField(
                "Buscar",
                icon: "magnifyingglass",
                text: $viewModel.query,
                prompt: "Título, autor o descripción",
                kind: .text,
                focus: $focus,
                field: .search
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            footer
        }
        .padding(IrisSpacing.xl)
        .presentationSizing(.page)
        .presentationBackground(IrisColor.canvasElevated)
        .task { await viewModel.load() }
        .task { await viewModel.observeChanges() }
    }

    // MARK: Header & footer

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agregar al servicio")
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                Group {
                    if viewModel.isLyricsOnly {
                        Text("Elige letras de tu biblioteca.")
                    } else {
                        Text("Elige letras, música, imágenes o videos de tu biblioteca.")
                    }
                }
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.irisIcon)
            .accessibilityLabel(Text("Cerrar"))
        }
    }

    private var footer: some View {
        HStack(spacing: IrisSpacing.md) {
            Text("Seleccionados: \(viewModel.selectionCount)")
                .font(IrisFont.calloutEmphasized)
                .foregroundStyle(viewModel.selectionCount > 0 ? IrisColor.textPrimary : IrisColor.textTertiary)
                .contentTransition(.numericText())
                .animation(IrisMotion.snappy, value: viewModel.selectionCount)

            Spacer()

            Button("Agregar al servicio") {
                viewModel.confirm()
            }
            .buttonStyle(.irisPrimary)
            .frame(width: 260)
            .disabled(viewModel.selectionCount == 0)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(IrisColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isLibraryEmpty {
            ContentUnavailableView {
                Label("Aún no hay canciones", systemImage: ServiceItem.Kind.song.systemImage)
            } description: {
                Text("Agrégalas desde la web de Iris.")
            }
            .foregroundStyle(IrisColor.textSecondary)
        } else if viewModel.isCurrentTabEmpty {
            ContentUnavailableView.search(text: viewModel.query)
                .foregroundStyle(IrisColor.textSecondary)
        } else {
            ScrollView {
                tabContent
                    .padding(.vertical, IrisSpacing.xxs)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.tab {
        case .lyrics:
            LazyVStack(spacing: IrisSpacing.sm) {
                ForEach(viewModel.filteredLyrics) { sheet in
                    LibraryRow(
                        icon: ServiceItem.Kind.song.systemImage,
                        tint: ServiceItem.Kind.song.tint,
                        title: sheet.title,
                        subtitle: sheet.author,
                        footnote: sheet.copyright,
                        preview: sheet.firstLine,
                        trailing: nil,
                        isSelected: viewModel.isSelected(.lyric(sheet.id))
                    ) {
                        viewModel.toggle(.lyric(sheet.id))
                    }
                }
            }

        case .music:
            LazyVStack(spacing: IrisSpacing.sm) {
                ForEach(viewModel.filteredMusic) { asset in
                    LibraryRow(
                        icon: ServiceItem.Kind.music.systemImage,
                        tint: ServiceItem.Kind.music.tint,
                        title: asset.title,
                        subtitle: asset.subtitle,
                        preview: nil,
                        trailing: asset.duration,
                        downloadState: asset.downloadState,
                        isSelected: viewModel.isSelected(.media(asset.id))
                    ) {
                        viewModel.toggle(.media(asset.id))
                    }
                }
            }

        case .images:
            mediaGrid(viewModel.filteredImages)

        case .videos:
            mediaGrid(viewModel.filteredVideos)
        }
    }

    private func mediaGrid(_ assets: [MediaAsset]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: IrisSpacing.md)], spacing: IrisSpacing.lg) {
            ForEach(assets) { asset in
                LibraryMediaTile(asset: asset, isSelected: viewModel.isSelected(.media(asset.id))) {
                    viewModel.toggle(.media(asset.id))
                }
            }
        }
    }
}

// MARK: - Rows & tiles

/// List row for lyrics and music.
struct LibraryRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    /// Copyright, under the author.
    var footnote: String?
    let preview: String?
    let trailing: String?
    var downloadState: MediaAsset.DownloadState = .ready
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)

        Button(action: action) {
            HStack(spacing: IrisSpacing.md) {
                Image(systemName: icon)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(IrisFont.calloutEmphasized)
                        .foregroundStyle(IrisColor.textPrimary)
                    Text(subtitle)
                        .font(IrisFont.caption)
                        .foregroundStyle(IrisColor.textTertiary)
                    if let footnote {
                        Text(footnote)
                            .font(IrisFont.caption)
                            .foregroundStyle(IrisColor.textTertiary)
                            .lineLimit(1)
                    }
                    if let preview {
                        Text(preview)
                            .font(.system(.callout, design: .serif))
                            .italic()
                            .foregroundStyle(IrisColor.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: IrisSpacing.sm)

                if downloadState != .ready {
                    DownloadBadge(state: downloadState)
                } else {
                    if let trailing {
                        Text(trailing)
                            .font(.system(.callout, design: .monospaced, weight: .medium))
                            .foregroundStyle(IrisColor.textSecondary)
                    }

                    IrisCheckmark(isOn: isSelected)
                }
            }
            .padding(IrisSpacing.md - 2)
            .background(isSelected ? IrisColor.surfaceRaised : IrisColor.surface, in: shape)
            .overlay {
                shape.strokeBorder(
                    isSelected ? AnyShapeStyle(IrisGradient.accent) : AnyShapeStyle(IrisColor.stroke),
                    lineWidth: isSelected ? 1.5 : 1
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(.irisPressable)
        .disabled(downloadState != .ready)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// "Descargando… 40 %", "Pendiente" or "No se pudo descargar" for a file not yet on the iPad.
struct DownloadBadge: View {
    let state: MediaAsset.DownloadState

    var body: some View {
        HStack(spacing: IrisSpacing.xs) {
            switch state {
            case let .downloading(progress):
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(IrisColor.textSecondary)
                Text("Descargando…")
            case .notDownloaded:
                Image(systemName: "icloud.and.arrow.down")
                Text("Descargando…")
            case .failed:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(IrisColor.warning)
                Text("No se pudo descargar")
            case .ready:
                EmptyView()
            }
        }
        .font(IrisFont.caption)
        .foregroundStyle(IrisColor.textSecondary)
    }
}

/// Grid tile for images and videos.
struct LibraryMediaTile: View {
    let asset: MediaAsset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous)

        Button(action: action) {
            VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                thumbnail
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(shape)
                    .overlay(alignment: .topTrailing) {
                        if asset.isAvailable {
                            IrisCheckmark(isOn: isSelected)
                                .padding(IrisSpacing.xs)
                        }
                    }
                    .overlay {
                        if !asset.isAvailable {
                            DownloadBadge(state: asset.downloadState)
                                .padding(.horizontal, IrisSpacing.sm)
                                .padding(.vertical, IrisSpacing.xs)
                                .background(.black.opacity(0.6), in: Capsule())
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = asset.duration {
                            Text(duration)
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(IrisSpacing.xs)
                        }
                    }
                    .overlay {
                        shape.strokeBorder(
                            isSelected ? AnyShapeStyle(IrisGradient.accent) : AnyShapeStyle(IrisColor.stroke),
                            lineWidth: isSelected ? 3 : 1
                        )
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.title)
                        .font(IrisFont.label)
                        .foregroundStyle(IrisColor.textPrimary)
                        .lineLimit(1)
                    Text(asset.subtitle)
                        .font(IrisFont.caption)
                        .foregroundStyle(IrisColor.textTertiary)
                }
                .padding(.horizontal, IrisSpacing.xxs)
            }
        }
        .buttonStyle(.irisPressable)
        .disabled(!asset.isAvailable)
        .accessibilityLabel(Text(asset.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var thumbnail: some View {
        LinearGradient(
            colors: asset.artwork.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            if let url = asset.localURL {
                MediaThumbnail(url: url, kind: asset.kind)
            }
        }
        .overlay {
            if asset.kind == .video {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.18), in: Circle())
            }
        }
    }
}

extension AddToServiceViewModel {
    /// Loaded view model for previews, optionally on a given tab.
    static func preview(tab: Tab = .lyrics, tabs: [Tab] = Tab.allCases) -> AddToServiceViewModel {
        let viewModel = AddToServiceViewModel(repository: MockLibraryRepository(latency: .zero), tabs: tabs) { _ in }
        viewModel.apply(lyrics: MockLibraryRepository.sampleLyrics, media: MockLibraryRepository.sampleMedia)
        viewModel.tab = tab
        if let first = MockLibraryRepository.sampleLyrics.first { viewModel.toggle(.lyric(first.id)) }
        viewModel.toggle(.media("v2"))
        return viewModel
    }
}

#Preview("Letras") {
    AddToServiceView(viewModel: .preview())
        .frame(width: 900, height: 820)
        .background(IrisColor.canvasElevated)
        .preferredColorScheme(.dark)
}

#Preview("Sin multimedia") {
    AddToServiceView(viewModel: .preview(tabs: [.lyrics]))
        .frame(width: 900, height: 820)
        .background(IrisColor.canvasElevated)
        .preferredColorScheme(.dark)
}

#Preview("Videos") {
    AddToServiceView(viewModel: .preview(tab: .videos))
        .frame(width: 900, height: 820)
        .background(IrisColor.canvasElevated)
        .preferredColorScheme(.dark)
}
