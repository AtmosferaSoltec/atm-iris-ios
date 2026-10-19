//
//  AddToServiceViewModel.swift
//  iris
//

import Foundation
import Observation
import SwiftUI

/// Browse the library in two tabs: Canciones (lyrics and their tracks) · Multimedia.
/// As a picker, items can be chosen across tabs and appended to the service in pick order;
/// in browse mode (Home › Biblioteca) it only shows what the church has.
@Observable
final class AddToServiceViewModel: Identifiable {
    enum Tab: Hashable, Identifiable, CaseIterable {
        /// Songs, each with its track if it has one · images and videos (Multimedia on the web).
        case songs, media

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .songs: "Canciones"
            case .media: "Multimedia"
            }
        }

        var searchPrompt: LocalizedStringKey {
            switch self {
            case .songs: "Título, autor o letra"
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
    /// Tabs allowed by the church's modules; only Canciones without Multimedia.
    let tabs: [Tab]
    let mode: Mode
    /// Plays the first seconds of a song's track.
    let preview = MusicPreviewPlayer()

    private(set) var isLoading = true
    private(set) var lyrics: [LyricSheet] = []
    /// Images and videos uploaded on the web (Multimedia).
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
        self.tab = tabs.first ?? .songs
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

    var filteredMedia: [MediaAsset] { media.filter { matches($0.title) } }

    /// The current tab has nothing at all yet (not a search without results).
    var isLibraryEmpty: Bool {
        switch tab {
        case .songs: lyrics.isEmpty
        case .media: media.isEmpty
        }
    }

    var isCurrentTabEmpty: Bool {
        switch tab {
        case .songs: filteredLyrics.isEmpty
        case .media: filteredMedia.isEmpty
        }
    }

    var isPicker: Bool { mode == .picker }

    var selectionCount: Int { selection.count }

    /// Without Multimedia there is nothing to switch between.
    var isSongsOnly: Bool { tabs == [.songs] }

    func isSelected(_ item: Selection) -> Bool {
        selection.contains(item)
    }

    // MARK: Intents

    func load() async {
        guard isLoading else { return }
        apply(
            lyrics: (try? await repository.lyrics()) ?? [],
            media: await repository.uploadedMedia()
        )
    }

    /// Installs library content. Also used by previews to start loaded.
    func apply(lyrics: [LyricSheet], media: [MediaAsset]) {
        self.lyrics = lyrics
        self.media = media
        isLoading = false
    }

    /// Reloads silently while open (new songs, download progress), until the calling task is cancelled.
    func observeChanges() async {
        for await _ in repository.changes() {
            guard !isLoading else { continue }
            lyrics = (try? await repository.lyrics()) ?? lyrics
            media = await repository.uploadedMedia()
            dropRemovedSelection()
        }
    }

    func toggle(_ item: Selection) {
        // Files not yet on this iPad can be picked too: adding them starts the download.
        guard isPicker else { return }
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

    /// A selection deleted on the web meanwhile can no longer be added.
    private func dropRemovedSelection() {
        selection.removeAll { item in
            switch item {
            case let .media(id): !media.contains { $0.id == id }
            case let .lyric(id): !lyrics.contains { $0.id == id }
            }
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
            return ServiceItem(lyric: sheet)

        case let .media(id):
            guard let asset = media.first(where: { $0.id == id }) else { return nil }
            return ServiceItem(asset: asset)
        }
    }
}
