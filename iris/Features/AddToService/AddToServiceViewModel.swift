//
//  AddToServiceViewModel.swift
//  iris
//

import Foundation
import Observation

/// Browse the library in four tabs and pick items to append to the service.
@Observable
final class AddToServiceViewModel: Identifiable {
    enum Tab: Hashable, Identifiable, CaseIterable {
        case lyrics, music, images, videos

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .lyrics: "Letras"
            case .music: "Música"
            case .images: "Imágenes"
            case .videos: "Videos"
            }
        }
    }

    /// Identifies anything selectable across tabs, in the order it was picked.
    enum Selection: Hashable {
        case lyric(LyricSheet.ID)
        case media(MediaAsset.ID)
    }

    // MARK: State

    var tab: Tab
    var query = ""
    /// Tabs allowed by the church's modules; only Letras without Multimedia.
    let tabs: [Tab]

    private(set) var isLoading = true
    private(set) var lyrics: [LyricSheet] = []
    private(set) var music: [MediaAsset] = []
    private(set) var images: [MediaAsset] = []
    private(set) var videos: [MediaAsset] = []
    private(set) var selection: [Selection] = []

    private let repository: any LibraryRepository
    private let onAdd: ([ServiceItem]) -> Void

    init(repository: any LibraryRepository, tabs: [Tab] = Tab.allCases, onAdd: @escaping ([ServiceItem]) -> Void) {
        self.repository = repository
        self.tabs = tabs
        self.tab = tabs.first ?? .lyrics
        self.onAdd = onAdd
    }

    // MARK: Derived

    var filteredLyrics: [LyricSheet] {
        lyrics.filter { matches($0.title) || matches($0.author) }
    }

    var filteredMusic: [MediaAsset] { music.filter { matches($0.title) || matches($0.subtitle) } }
    var filteredImages: [MediaAsset] { images.filter { matches($0.title) } }
    var filteredVideos: [MediaAsset] { videos.filter { matches($0.title) } }

    var isCurrentTabEmpty: Bool {
        switch tab {
        case .lyrics: filteredLyrics.isEmpty
        case .music: filteredMusic.isEmpty
        case .images: filteredImages.isEmpty
        case .videos: filteredVideos.isEmpty
        }
    }

    var selectionCount: Int { selection.count }

    /// Without Multimedia there is nothing to switch between.
    var isLyricsOnly: Bool { tabs == [.lyrics] }

    func isSelected(_ item: Selection) -> Bool {
        selection.contains(item)
    }

    // MARK: Intents

    func load() async {
        guard lyrics.isEmpty else { return }
        isLoading = true
        apply(
            lyrics: (try? await repository.lyrics()) ?? [],
            media: ((try? await repository.media(of: .music)) ?? [])
                + ((try? await repository.media(of: .image)) ?? [])
                + ((try? await repository.media(of: .video)) ?? [])
        )
    }

    /// Installs library content. Also used by previews to start loaded.
    func apply(lyrics: [LyricSheet], media: [MediaAsset]) {
        self.lyrics = lyrics
        music = media.filter { $0.kind == .music }
        images = media.filter { $0.kind == .image }
        videos = media.filter { $0.kind == .video }
        isLoading = false
    }

    func toggle(_ item: Selection) {
        if let index = selection.firstIndex(of: item) {
            selection.remove(at: index)
        } else {
            selection.append(item)
        }
    }

    func confirm() {
        let items = selection.compactMap(serviceItem(for:))
        guard !items.isEmpty else { return }
        onAdd(items)
    }

    // MARK: Private

    private func matches(_ text: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func serviceItem(for selection: Selection) -> ServiceItem? {
        switch selection {
        case let .lyric(id):
            guard let sheet = lyrics.first(where: { $0.id == id }) else { return nil }
            return ServiceItem(kind: .song, title: sheet.title, subtitle: sheet.author, slides: sheet.sections)

        case let .media(id):
            guard let asset = (music + images + videos).first(where: { $0.id == id }) else { return nil }
            switch asset.kind {
            case .music:
                return ServiceItem(
                    kind: .music,
                    title: asset.title,
                    subtitle: "\(asset.subtitle) · \(asset.duration ?? "")",
                    slides: [Slide(content: .audio(title: asset.title, duration: asset.duration ?? ""))]
                )
            case .image:
                return ServiceItem(
                    kind: .image,
                    title: asset.title,
                    subtitle: asset.subtitle,
                    slides: [Slide(content: .image(title: asset.title, artwork: asset.artwork))]
                )
            case .video:
                return ServiceItem(
                    kind: .video,
                    title: asset.title,
                    subtitle: String(localized: "Video · \(asset.duration ?? "")"),
                    slides: [Slide(content: .video(title: asset.title, duration: asset.duration ?? ""))]
                )
            }
        }
    }
}
