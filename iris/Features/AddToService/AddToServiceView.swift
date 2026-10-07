//
//  AddToServiceView.swift
//  iris
//

import SwiftUI

/// Library browser with three tabs: Letras · Música · Multimedia.
/// As a picker, items can be chosen across tabs and are appended to the service in pick order.
/// In browse mode (Home › Biblioteca) it only shows the library.
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
                prompt: viewModel.tab.searchPrompt,
                kind: .text,
                focus: $focus,
                field: .search
            )

            if viewModel.tab == .music {
                musicDownloadHint
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if viewModel.isPicker {
                footer
            }
        }
        .padding(IrisSpacing.xl)
        .presentationSizing(.page)
        .presentationBackground(IrisColor.canvasElevated)
        .task { await viewModel.load() }
        .task { await viewModel.observeChanges() }
        .onChange(of: viewModel.tab) { viewModel.preview.stop() }
        .onDisappear { viewModel.preview.stop() }
    }

    // MARK: Header & footer

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if viewModel.isPicker {
                    Text("Agregar al servicio")
                        .font(IrisFont.title)
                        .foregroundStyle(IrisColor.textPrimary)
                    Group {
                        if viewModel.isLyricsOnly {
                            Text("Elige letras de tu biblioteca.")
                        } else {
                            Text("Elige letras, música o multimedia para tu servicio.")
                        }
                    }
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
                } else {
                    Text("Tu biblioteca")
                        .font(IrisFont.title)
                        .foregroundStyle(IrisColor.textPrimary)
                    Text("Letras, música y multimedia que subiste desde la web.")
                        .font(IrisFont.callout)
                        .foregroundStyle(IrisColor.textSecondary)
                }
            }
            Spacer()
            if viewModel.isPicker {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.irisIcon)
                .accessibilityLabel(Text("Cerrar"))
            }
        }
    }

    /// Where the tracks come from and when they reach this iPad.
    private var musicDownloadHint: some View {
        HStack(spacing: IrisSpacing.md) {
            Image(systemName: "icloud.and.arrow.down")
                .foregroundStyle(ServiceItem.Kind.music.tint)
            Text("Se suben desde la web, en Música. Al agregarlas al servicio se descargan y quedan en este iPad.")
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
            Spacer(minLength: 0)
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
            emptyLibrary
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
    private var emptyLibrary: some View {
        switch viewModel.tab {
        case .lyrics:
            ContentUnavailableView {
                Label("Aún no hay canciones", systemImage: ServiceItem.Kind.song.systemImage)
            } description: {
                Text("Agrégalas desde la web de Iris.")
            }
            .foregroundStyle(IrisColor.textSecondary)
        case .music:
            ContentUnavailableView {
                Label("Aún no hay música", systemImage: ServiceItem.Kind.music.systemImage)
            } description: {
                Text("Sube tus pistas (MP3, M4A, WAV…) desde la web de Iris, en Música.")
            }
            .foregroundStyle(IrisColor.textSecondary)
        case .media:
            ContentUnavailableView {
                Label("Aún no hay multimedia", systemImage: "photo.on.rectangle.angled")
            } description: {
                Text("Sube imágenes o videos desde la web de Iris, en Multimedia, y aparecerán aquí.")
            }
            .foregroundStyle(IrisColor.textSecondary)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.tab {
        case .lyrics:
            LazyVStack(spacing: IrisSpacing.xxs) {
                ForEach(viewModel.filteredLyrics) { sheet in
                    LibraryRow(
                        leading: .icon(ServiceItem.Kind.song.systemImage, tint: ServiceItem.Kind.song.tint),
                        title: sheet.title,
                        subtitle: sheet.author,
                        trailing: nil,
                        showsSelection: viewModel.isPicker,
                        isSelected: viewModel.isSelected(.lyric(sheet.id))
                    ) {
                        viewModel.toggle(.lyric(sheet.id))
                    }
                }
            }

        case .music:
            LazyVStack(spacing: IrisSpacing.xxs) {
                ForEach(viewModel.filteredMusic) { asset in
                    LibraryRow(
                        leading: .icon(ServiceItem.Kind.music.systemImage, tint: ServiceItem.Kind.music.tint),
                        title: asset.title,
                        subtitle: asset.subtitle,
                        trailing: asset.duration,
                        downloadState: asset.downloadState,
                        showsSelection: viewModel.isPicker,
                        preview: asset.localURL.map { PreviewControl(player: viewModel.preview, url: $0) },
                        isSelected: viewModel.isSelected(.media(asset.id))
                    ) {
                        viewModel.toggle(.media(asset.id))
                    }
                }
            }

        case .media:
            LazyVStack(spacing: IrisSpacing.xxs) {
                ForEach(viewModel.filteredMedia) { asset in
                    LibraryRow(
                        leading: .thumbnail(asset),
                        title: asset.title,
                        subtitle: asset.subtitle,
                        trailing: asset.duration,
                        downloadState: asset.downloadState,
                        showsSelection: viewModel.isPicker,
                        isSelected: viewModel.isSelected(.media(asset.id))
                    ) {
                        viewModel.toggle(.media(asset.id))
                    }
                }
            }
        }
    }
}

// MARK: - Rows

/// Flat list row for lyrics, music, images and videos: icon or thumbnail, title with the
/// subtitle dimmed, duration, selection. No card fill or border — only the selected row raises,
/// with the accent bar on the leading edge (the look of `ServiceItemRow`, carried over from Windows).
struct LibraryRow: View {
    enum Leading {
        case icon(String, tint: Color)
        case thumbnail(MediaAsset)
    }

    let leading: Leading
    let title: String
    let subtitle: String
    let trailing: String?
    var downloadState: MediaAsset.DownloadState = .ready
    /// Hidden when only browsing.
    var showsSelection = true
    /// A play button over the icon, to hear the first seconds of a song.
    var preview: PreviewControl?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)

        Button(action: action) {
            HStack(spacing: IrisSpacing.md) {
                leadingView

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(IrisFont.calloutEmphasized)
                        .foregroundStyle(IrisColor.textPrimary)
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(IrisFont.caption)
                            .foregroundStyle(IrisColor.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: IrisSpacing.sm)

                if downloadState != .ready {
                    DownloadBadge(state: downloadState)
                } else if let trailing {
                    Text(trailing)
                        .font(.system(.callout, design: .monospaced, weight: .medium))
                        .foregroundStyle(IrisColor.textSecondary)
                }

                if showsSelection {
                    IrisCheckmark(isOn: isSelected)
                }
            }
            .padding(.horizontal, IrisSpacing.sm)
            .padding(.vertical, IrisSpacing.sm - 2)
            .background {
                if isSelected {
                    shape.fill(IrisColor.surfaceRaised)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(IrisGradient.accent)
                                .frame(width: 3)
                                .padding(.vertical, IrisSpacing.xs)
                        }
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.irisPressable)
        .disabled(!showsSelection)
        // Outside the row's button, so playing never selects the song. It sits where the icon is.
        .overlay(alignment: .leading) {
            if let preview {
                PreviewPlayButton(control: preview, tint: leadingTint)
                    .padding(.leading, IrisSpacing.sm)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case let .icon(name, tint):
            Image(systemName: name)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous))

        case let .thumbnail(asset):
            LibraryThumbnail(asset: asset)
        }
    }

    private var leadingTint: Color {
        if case let .icon(_, tint) = leading { return tint }
        return ServiceItem.Kind.music.tint
    }
}

/// Small square preview for an image or video entry: the real picture, or an artwork gradient
/// while it is still only in the cloud; a play mark for videos.
struct LibraryThumbnail: View {
    let asset: MediaAsset
    var size: CGFloat = 44

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous)

        ZStack {
            LinearGradient(
                colors: asset.artwork.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let url = asset.localURL {
                MediaThumbnail(url: url, kind: asset.kind)
            }
            if asset.kind == .video {
                Image(systemName: "play.fill")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay { shape.strokeBorder(IrisColor.stroke) }
    }
}

/// What a row needs to preview its song.
struct PreviewControl {
    let player: MusicPreviewPlayer
    let url: URL
}

/// Play / stop over a song's icon tile.
struct PreviewPlayButton: View {
    let control: PreviewControl
    let tint: Color

    var body: some View {
        let isPlaying = control.player.isPlaying(control.url)
        Button {
            control.player.toggle(control.url)
        } label: {
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(isPlaying ? IrisColor.canvas : tint)
                .frame(width: 44, height: 44)
                .background(isPlaying ? tint : tint.opacity(0.14), in: RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous))
        }
        .buttonStyle(.irisPressable)
        .accessibilityLabel(Text(isPlaying ? "Detener" : "Escuchar un momento"))
    }
}

/// "Descargando…", "En la nube" or "No se pudo descargar" for a file not yet on the iPad.
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
                Image(systemName: "icloud")
                Text("En la nube")
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
    /// Hidden when only browsing.
    var showsSelection = true
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
                        if showsSelection {
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
        .disabled(!showsSelection)
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
            // Songs are only an icon.
            if asset.kind == .music {
                Image(systemName: ServiceItem.Kind.music.systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
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
    static func preview(tab: Tab = .lyrics, tabs: [Tab] = Tab.allCases, mode: Mode = .picker) -> AddToServiceViewModel {
        let viewModel = AddToServiceViewModel(repository: MockLibraryRepository(latency: .zero), tabs: tabs, mode: mode)
        let sample = MockLibraryRepository.sampleMedia
        viewModel.apply(
            lyrics: MockLibraryRepository.sampleLyrics,
            music: sample.filter { $0.kind == .music },
            media: sample.filter { $0.kind != .music }
        )
        viewModel.tab = tab
        if mode == .picker {
            if let first = MockLibraryRepository.sampleLyrics.first { viewModel.toggle(.lyric(first.id)) }
            viewModel.toggle(.media("v2"))
        }
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

#Preview("Multimedia") {
    AddToServiceView(viewModel: .preview(tab: .media))
        .frame(width: 900, height: 820)
        .background(IrisColor.canvasElevated)
        .preferredColorScheme(.dark)
}
