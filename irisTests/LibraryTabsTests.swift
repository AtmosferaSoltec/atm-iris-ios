//
//  LibraryTabsTests.swift
//  irisTests
//
//  Letras · Música · Multimedia, all uploaded on the web.
//

import Foundation
import Testing
@testable import iris

@MainActor
struct LibraryTabsTests {
    private func loaded(mode: AddToServiceViewModel.Mode = .picker) -> AddToServiceViewModel {
        let viewModel = AddToServiceViewModel(repository: MockLibraryRepository(latency: .zero), mode: mode)
        let sample = MockLibraryRepository.sampleMedia
        viewModel.apply(
            lyrics: MockLibraryRepository.sampleLyrics,
            music: sample.filter { $0.kind == .music },
            media: sample.filter { $0.kind != .music }
        )
        return viewModel
    }

    @Test func hasThreeTabs() {
        #expect(AddToServiceViewModel.Tab.allCases == [.lyrics, .music, .media])
    }

    @Test func musicIsFoundByNameOnly() {
        let viewModel = loaded()
        viewModel.tab = .music
        viewModel.query = "preludio"
        #expect(viewModel.filteredMusic.map(\.title) == ["Preludio en Re"])
        // "Órgano" is only in the subtitle, not in the name.
        viewModel.query = "organo"
        #expect(viewModel.filteredMusic.isEmpty)
    }

    @Test func multimediaHasImagesAndVideosAndMusicHasItsOwnTab() async throws {
        let repository = MockLibraryRepository(latency: .zero)
        let uploaded = await repository.uploadedMedia()
        #expect(Set(uploaded.map(\.kind)) == [.image, .video])
        #expect(await repository.music().allSatisfy { $0.kind == .music })
        #expect(await !repository.music().isEmpty)
    }

    @Test func backgroundsAreNotListedInMultimedia() async {
        struct WithBackground: LibraryRepository {
            func lyrics() async throws -> [LyricSheet] { [] }
            func media(of kind: MediaAsset.Kind) async throws -> [MediaAsset] {
                guard kind == .image else { return [] }
                var background = MediaAsset(id: "bg", kind: .image, title: "Fondo", subtitle: "", duration: nil, artwork: [0, 0])
                background.isBackground = true
                return [background, MediaAsset(id: "i", kind: .image, title: "Anuncio", subtitle: "", duration: nil, artwork: [0, 0])]
            }
        }
        #expect(await WithBackground().uploadedMedia().map(\.id) == ["i"])
    }

    @Test func browsingDoesNotSelect() {
        let viewModel = loaded(mode: .browse)
        if let first = viewModel.lyrics.first { viewModel.toggle(.lyric(first.id)) }
        #expect(viewModel.selectionCount == 0)
    }

    @Test func aSelectedSongCanBeAddedToTheService() {
        let viewModel = loaded()
        viewModel.toggle(.media("m1"))
        #expect(viewModel.selectionCount == 1)
    }

    @Test func musicStillInTheCloudCanBeAddedAndKeepsItsLibraryID() throws {
        var track = MockLibraryRepository.sampleMedia[0]
        track.downloadState = .notDownloaded
        var added: [ServiceItem] = []
        let picker = AddToServiceViewModel(repository: MockLibraryRepository(latency: .zero)) { added = $0 }
        picker.apply(lyrics: [], music: [track], media: [])
        picker.toggle(.media(track.id))
        picker.confirm()

        let item = try #require(added.first)
        #expect(item.kind == .music)
        #expect(item.mediaID == track.id)
        #expect(item.slides.first?.content.url == nil)
    }

    @Test func cachedFileNamesGiveBackTheMediaID() {
        #expect(MediaCache.mediaID(ofFile: "0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b-1760000000000.mp3") == "0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b")
        #expect(MediaCache.mediaID(ofFile: "singuion.mp3") == nil)
    }

    // MARK: Quick listen

    /// One second of silence as a 8 kHz mono WAV.
    private func silentWAV() throws -> URL {
        let samples = 8_000
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + samples * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(8_000)); append(UInt32(16_000)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(samples * 2))
        data.append(Data(count: samples * 2))
        let url = URL.temporaryDirectory.appending(path: "silencio-\(UUID().uuidString).wav")
        try data.write(to: url)
        return url
    }

    @Test func previewPlaysAndStopsOnSecondTap() throws {
        let url = try silentWAV()
        defer { try? FileManager.default.removeItem(at: url) }
        let player = MusicPreviewPlayer()

        player.toggle(url)
        #expect(player.isPlaying(url))
        player.toggle(url)
        #expect(!player.isPlaying(url))
    }

    @Test func previewOfAnotherSongReplacesTheFirst() throws {
        let first = try silentWAV()
        let second = try silentWAV()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let player = MusicPreviewPlayer()

        player.toggle(first)
        player.toggle(second)
        #expect(!player.isPlaying(first))
        #expect(player.isPlaying(second))
        player.stop()
        #expect(player.playingURL == nil)
    }

    @Test func aFileThatCannotBeOpenedDoesNotPlay() throws {
        let broken = URL.temporaryDirectory.appending(path: "roto-\(UUID().uuidString).mp3")
        try Data("no es audio".utf8).write(to: broken)
        defer { try? FileManager.default.removeItem(at: broken) }
        let player = MusicPreviewPlayer()

        player.toggle(broken)
        #expect(player.playingURL == nil)
    }
}
