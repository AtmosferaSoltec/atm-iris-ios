//
//  AddToServiceViewModel.swift
//  iris
//

import Foundation
import Observation
import SwiftUI

/// Browse the library in three tabs: Letras · Música · Multimedia.
/// As a picker, items can be chosen across tabs and appended to the service in pick order;
/// in browse mode (Home › Biblioteca) it only shows what the church has.
@Observable
final class AddToServiceViewModel: Identifiable {
    enum Tab: Hashable, Identifiable, CaseIterable {
        /// Lyrics from the library · songs stored on this iPad · everything uploaded on the web.
        case lyrics, music, media

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .lyrics: "Letras"
            case .music: "Música"
            case .media: "Multimedia"
            }
        }

        var searchPrompt: LocalizedStringKey {
            switch self {
            case .lyrics: "Título, autor o letra"
            case .music: "Nombre de la canción"
            case .media: "Nombre del archivo"
            }
        }
    }

    enum Mode { case picker, browse }

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
    let mode: Mode
    /// Plays the first seconds of a song from the Música tab.
    let preview = MusicPreviewPlayer()

    private(set) var isLoading = true
    private(set) var lyrics: [LyricSheet] = []
    /// Songs in the "Música" folder of this iPad.
    private(set) var music: [MediaAsset] = []
    /// Images, videos and audio uploaded on the web.
    private(set) var media: [MediaAsset] = []
    private(set) var selection: [Selection] = []

    private let repository: any LibraryRepository
    private let onAdd: ([ServiceItem]) -> Void

    init(
        repository: any LibraryRepository,
        tabs: [Tab] = Tab.allCases,
        mode: Mode = .picker,
        onAdd: @escaping ([ServiceItem]) -> Void = { _ in }
    ) {
        self.repository = repository
        self.tabs = tabs
        self.mode = mode
        self.tab = tabs.first ?? .lyrics
        self.onAdd = onAdd
    }

    // MARK: Derived

    var filteredLyrics: [LyricSheet] {
        lyrics.filter { sheet in
            matches(sheet.title) || matches(sheet.author) || sheet.sections.contains { section in
                if case let .text(text, _) = section.content { return matches(text) }
                return false
            }
        }
    }

    /// Music is found by the song's name, which is the file's name.
    var filteredMusic: [MediaAsset] { music.filter { matches($0.title) } }
    var filteredMedia: [MediaAsset] { media.filter { matches($0.title) } }

    /// The current tab has nothing at all yet (not a search without results).
    var isLibraryEmpty: Bool {
        switch tab {
        case .lyrics: lyrics.isEmpty
        case .music: music.isEmpty
        case .media: media.isEmpty
        }
    }

    var isCurrentTabEmpty: Bool {
        switch tab {
        case .lyrics: filteredLyrics.isEmpty
        case .music: filteredMusic.isEmpty
        case .media: filteredMedia.isEmpty
        }
    }

    var isPicker: Bool { mode == .picker }

    var selectionCount: Int { selection.count }

    /// Without Multimedia there is nothing to switch between.
    var isLyricsOnly: Bool { tabs == [.lyrics] }

    func isSelected(_ item: Selection) -> Bool {
        selection.contains(item)
    }

    // MARK: Intents

    func load() async {
        guard isLoading else { return }
        apply(
            lyrics: (try? await repository.lyrics()) ?? [],
            music: await repository.localMusic(),
            media: await repository.uploadedMedia()
        )
    }

    /// Installs library content. Also used by previews to start loaded.
    func apply(lyrics: [LyricSheet], music: [MediaAsset], media: [MediaAsset]) {
        self.lyrics = lyrics
        self.music = music
        self.media = media
        isLoading = false
    }

    /// Looks at the "Música" folder again: songs may have been copied in from the Files app.
    func refreshMusic() async {
        music = await repository.localMusic()
        dropUnavailableSelection()
    }

    /// Reloads silently while open (new songs, download progress), until the calling task is cancelled.
    func observeChanges() async {
        for await _ in repository.changes() {
            guard !isLoading else { continue }
            lyrics = (try? await repository.lyrics()) ?? lyrics
            media = await repository.uploadedMedia()
            dropUnavailableSelection()
        }
    }

    func toggle(_ item: Selection) {
        guard isPicker else { return }
        // Files still downloading cannot be added: the service must work offline.
        if case let .media(id) = item, (music + media).first(where: { $0.id == id })?.isAvailable == false { return }
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

    /// A selection whose file disappeared can no longer be added.
    private func dropUnavailableSelection() {
        selection.removeAll { item in
            if case let .media(id) = item { return !(music + media).contains { $0.id == id && $0.isAvailable } }
            return false
        }
    }

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
            guard let asset = (music + media).first(where: { $0.id == id }) else { return nil }
            switch asset.kind {
            case .music:
                return ServiceItem(
                    kind: .music,
                    title: asset.title,
                    subtitle: "\(asset.subtitle) · \(asset.duration ?? "")",
                    slides: [Slide(content: .audio(title: asset.title, duration: asset.duration ?? "", url: asset.localURL))]
                )
            case .image:
                return ServiceItem(
                    kind: .image,
                    title: asset.title,
                    subtitle: asset.subtitle,
                    slides: [Slide(content: .image(title: asset.title, artwork: asset.artwork, url: asset.localURL))]
                )
            case .video:
                return ServiceItem(
                    kind: .video,
                    title: asset.title,
                    subtitle: String(localized: "Video · \(asset.duration ?? "")"),
                    slides: [Slide(content: .video(title: asset.title, duration: asset.duration ?? "", url: asset.localURL))]
                )
            }
        }
    }
}
