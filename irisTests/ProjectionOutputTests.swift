//
//  ProjectionOutputTests.swift
//  irisTests
//
//  What reaches the TV. The TV shows only the live frame (never the console), it changes only when
//  something goes live, and the external view draws nothing but the projection.
//

import AVFoundation
import SwiftUI
import Testing
import UIKit
@testable import iris

/// Records every frame sent to the TV and lets a test plug and unplug the display.
@MainActor
private final class RecordingDisplayOutput: DisplayOutputService {
    private(set) var frames: [ProjectionFrame] = []
    var display: ExternalDisplay? = ExternalDisplay(name: "Sala principal", resolution: "1920 × 1080")
    private var continuation: AsyncStream<ExternalDisplay?>.Continuation?

    var lastFrame: ProjectionFrame? { frames.last }

    func connectedDisplay() async -> ExternalDisplay? { display }

    func displayUpdates() -> AsyncStream<ExternalDisplay?> {
        let (stream, continuation) = AsyncStream.makeStream(of: ExternalDisplay?.self)
        self.continuation = continuation
        continuation.yield(display)
        return stream
    }

    func present(_ frame: ProjectionFrame) { frames.append(frame) }

    var videoPlayer: AVPlayer? { nil }

    func plug(_ display: ExternalDisplay?) {
        self.display = display
        continuation?.yield(display)
    }

    func finish() { continuation?.finish() }
}

@MainActor
struct ProjectionOutputTests {
    private let store = InMemoryChurchStore()

    private func console(output: RecordingDisplayOutput, modules: ChurchModules = ChurchModules()) -> LiveConsoleViewModel {
        LiveConsoleViewModel(
            session: .preview,
            serviceType: store.serviceTypes[0],
            modules: modules,
            people: store.people,
            servicePlanRepository: EmptyServicePlanRepository(),
            projectionSettings: MockProjectionSettingsRepository(store: store, latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(latency: .zero),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: output,
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            peopleRepository: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
    }

    private let song = ServiceItem(kind: .song, title: "Sublime gracia", subtitle: "John Newton", slides: [
        Slide(label: "Estrofa 1", content: .text("Sublime gracia del Señor", footnote: nil)),
        Slide(label: "Coro", content: .text("que a un pecador salvó", footnote: nil))
    ])
    private let image = ServiceItem(kind: .image, title: "Anuncio", subtitle: "", slides: [
        Slide(content: .image(title: "Anuncio", artwork: [0x111111, 0x222222]))
    ])
    private let video = ServiceItem(kind: .video, title: "Testimonio", subtitle: "", slides: [
        Slide(content: .video(title: "Testimonio", duration: "0:45"))
    ])
    private let music = ServiceItem(kind: .music, title: "Preludio", subtitle: "", slides: [
        Slide(content: .audio(title: "Preludio", duration: "3:40"))
    ])

    private func loaded(_ items: [ServiceItem] = []) async -> (LiveConsoleViewModel, RecordingDisplayOutput) {
        let output = RecordingDisplayOutput()
        let viewModel = console(output: output)
        await viewModel.load()
        if !items.isEmpty { viewModel.appendToService(items) }
        return (viewModel, output)
    }

    // MARK: Console → TV

    @Test func anEmptyServiceKeepsTheTVBlank() async {
        let (_, output) = await loaded()
        #expect(output.lastFrame?.content == .blank)
        #expect(output.frames.allSatisfy { $0.content == .blank })
    }

    @Test func openingASongDoesNotShowItUntilItGoesLive() async {
        let (viewModel, output) = await loaded([song])
        // The item is open on the iPad, ready to drive: the TV has not changed.
        #expect(viewModel.selectedItemID == song.id)
        #expect(output.lastFrame?.content == .blank)

        viewModel.goLive(slideIndex: 0)
        #expect(output.lastFrame?.content == .text("Sublime gracia del Señor", footnote: nil))
    }

    @Test func nextAndPreviousMoveTheTV() async {
        let (viewModel, output) = await loaded([song])
        viewModel.goLive(slideIndex: 0)

        viewModel.next()
        #expect(output.lastFrame?.content == .text("que a un pecador salvó", footnote: nil))
        #expect(!viewModel.canGoNext)

        viewModel.previous()
        #expect(output.lastFrame?.content == .text("Sublime gracia del Señor", footnote: nil))
    }

    @Test func clearingTheScreenLeavesOnlyTheBackground() async {
        let (viewModel, output) = await loaded([song])
        viewModel.goLive(slideIndex: 0)
        let background = viewModel.selectedBackground

        viewModel.toggleClearScreen()
        #expect(output.lastFrame == ProjectionFrame(background: background, content: .blank))

        viewModel.toggleClearScreen()
        #expect(output.lastFrame?.content == .text("Sublime gracia del Señor", footnote: nil))
    }

    @Test func goingLiveAgainUndoesAClearedScreen() async {
        let (viewModel, output) = await loaded([song])
        viewModel.goLive(slideIndex: 0)
        viewModel.toggleClearScreen()

        viewModel.goLive(slideIndex: 1)
        #expect(output.lastFrame?.content == .text("que a un pecador salvó", footnote: nil))
    }

    @Test func changingTheBackgroundReachesTheTV() async throws {
        let (viewModel, output) = await loaded([song])
        viewModel.goLive(slideIndex: 0)
        let other = try #require(MockBackgroundRepository.sample.dropFirst().first)

        viewModel.selectBackground(other.id)
        #expect(output.lastFrame?.background == other)
        #expect(output.lastFrame?.content == .text("Sublime gracia del Señor", footnote: nil))
    }

    @Test func imagesAndVideosGoToTheTV() async {
        let (viewModel, output) = await loaded([image, video])

        viewModel.selectItem(image.id)
        viewModel.presentSelectedMedia()
        #expect(output.lastFrame?.content == .image(title: "Anuncio", artwork: [0x111111, 0x222222]))

        viewModel.selectItem(video.id)
        viewModel.presentSelectedMedia()
        #expect(output.lastFrame?.content == .video(title: "Testimonio", duration: "0:45"))
        #expect(viewModel.playback?.kind == .video)
    }

    @Test func musicPlaysInTheRoomWithoutChangingTheTV() async {
        let (viewModel, output) = await loaded([song, music])
        viewModel.selectItem(song.id)
        viewModel.goLive(slideIndex: 0)
        let onScreen = output.lastFrame

        viewModel.selectItem(music.id)
        viewModel.presentSelectedMedia()
        #expect(output.lastFrame == onScreen)
        #expect(viewModel.playback?.kind == .music)
    }

    @Test func removingTheLiveSongDoesNotCrashTheTV() async {
        let (viewModel, output) = await loaded([song])
        viewModel.goLive(slideIndex: 0)
        viewModel.removeItem(song.id)
        #expect(viewModel.items.isEmpty)
        #expect(output.lastFrame != nil)
    }

    // MARK: TV connecting and disconnecting

    @Test func theConsoleFollowsTheTVPluggingAndUnplugging() async throws {
        let (viewModel, output) = await loaded()
        let watching = Task { await viewModel.observeDisplay() }
        defer { watching.cancel() }

        output.plug(nil)
        try await waitUntil { viewModel.display == nil }

        let tv = ExternalDisplay(name: "Pantalla externa", resolution: "3840 × 2160")
        output.plug(tv)
        try await waitUntil { viewModel.display == tv }
        output.finish()
    }

    @Test func unpluggingTheTVKeepsTheServiceGoing() async throws {
        let (viewModel, output) = await loaded([song])
        let watching = Task { await viewModel.observeDisplay() }
        defer { watching.cancel() }
        viewModel.goLive(slideIndex: 0)

        output.plug(nil)
        try await waitUntil { viewModel.display == nil }
        viewModel.next()
        #expect(output.lastFrame?.content == .text("que a un pecador salvó", footnote: nil))
        output.finish()
    }

    // MARK: Projection store (shared by the console and the TV scene)

    @Test func theStoreHoldsWhatTheConsolePresents() {
        let projection = ProjectionStore()
        let service = LiveDisplayOutputService(store: projection)
        let frame = ProjectionFrame(background: nil, content: .text("Aleluya", footnote: nil))

        service.present(frame)
        #expect(projection.frame == frame)
    }

    @Test func displayUpdatesStartWithTheCurrentScreenThenFollowChanges() async {
        let projection = ProjectionStore()
        let tv = ExternalDisplay(name: "Pantalla externa", resolution: "1920 × 1080")
        var updates = projection.displayUpdates().makeAsyncIterator()

        #expect(await updates.next() == .some(nil))
        projection.display = tv
        #expect(await updates.next() == .some(tv))
        projection.display = nil
        #expect(await updates.next() == .some(nil))
    }

    @Test func settingTheSameScreenTwiceDoesNotRepeatTheUpdate() async {
        let projection = ProjectionStore()
        let tv = ExternalDisplay(name: "Pantalla externa", resolution: "1920 × 1080")
        projection.display = tv
        var updates = projection.displayUpdates().makeAsyncIterator()
        #expect(await updates.next() == .some(tv))

        projection.display = tv
        projection.display = nil
        #expect(await updates.next() == .some(nil))
    }

    // MARK: The TV's own view

    @Test func describesTheScreenInPixelsWhateverItsOrientation() {
        let landscape = ExternalDisplay.describe(pointSize: CGSize(width: 960, height: 540), scale: 2)
        let portrait = ExternalDisplay.describe(pointSize: CGSize(width: 540, height: 960), scale: 2)
        #expect(landscape.resolution == "1920 × 1080")
        #expect(portrait.resolution == "1920 × 1080")
        // No AirPlay route in tests: a cable or simulated screen is just "Pantalla externa".
        #expect(landscape.name == "Pantalla externa")
    }

    @Test func aBlankTVIsCompletelyBlack() throws {
        let projection = ProjectionStore()
        projection.frame = .black
        let brightness = try render(ExternalProjectionView(store: projection))
        #expect(brightness.max == 0)
    }

    @Test func aSlideOnTheTVShowsItsText() throws {
        let projection = ProjectionStore()
        projection.frame = ProjectionFrame(background: nil, content: .text("Santo, santo, santo", footnote: nil))
        let brightness = try render(ExternalProjectionView(store: projection))
        // White text on black: bright pixels exist, the rest stays black.
        #expect(brightness.max > 200)
        #expect(brightness.mean < 60)
    }

    @Test func aClearedScreenShowsOnlyTheBackground() throws {
        let projection = ProjectionStore()
        let background = try #require(MockBackgroundRepository.sample.first)
        projection.frame = ProjectionFrame(background: background, content: .blank)
        let brightness = try render(ExternalProjectionView(store: projection))
        // A gradient, not black, and no text drawn over it.
        #expect(brightness.max > 0)
    }

    // MARK: Helpers

    /// Polls a condition the console reaches asynchronously.
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    /// Renders a TV-sized view and returns its luminance (0–255): the brightest pixel and the mean.
    private func render(_ view: some View) throws -> (max: Int, mean: Int) {
        let renderer = ImageRenderer(content: view.frame(width: 960, height: 540))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var maximum = 0, total = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let luminance = (Int(pixels[index]) * 299 + Int(pixels[index + 1]) * 587 + Int(pixels[index + 2]) * 114) / 1000
            maximum = max(maximum, luminance)
            total += luminance
        }
        return (maximum, total / (width * height))
    }
}
