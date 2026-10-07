//
//  ProjectionSettingsTests.swift
//  irisTests
//
//  Typeface, size and default background of the projected lyrics (contract §6): the settings
//  screen, and how a new service starts because of them.
//

import Foundation
import SwiftUI
import Testing
@testable import iris

@MainActor
struct ProjectionSettingsTests {
    // MARK: Contract round-trip

    @Test func decodesAndEncodesTheSameSettings() throws {
        let json = """
        {"fontFamily":"georgia","fontSizePt":112,"defaultBackgroundId":"media-abc"}
        """
        let dto = try JSONCoding.decoder.decode(ProjectionSettingsDTO.self, from: Data(json.utf8))
        let settings = ProjectionSettings(dto)
        #expect(settings == ProjectionSettings(fontFamily: .georgia, fontSizePt: 112, defaultBackgroundId: "media-abc"))

        let reencoded = try JSONCoding.decoder.decode(ProjectionSettingsDTO.self, from: JSONCoding.encoder.encode(settings.dto))
        #expect(reencoded == dto)
    }

    @Test func aNullDefaultBackgroundTravelsAsNullNeverOmitted() throws {
        let data = try JSONCoding.encoder.encode(ProjectionSettings().dto)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object.keys.contains("defaultBackgroundId"))
        #expect(object["defaultBackgroundId"] is NSNull)
    }

    @Test func anOlderServerWithoutProjectionGetsTheRecommendedDefaults() {
        #expect(ProjectionSettings(nil) == ProjectionSettings())
        #expect(ProjectionSettings().fontFamily == .system)
        #expect(ProjectionSettings().fontSizePt == 88)
    }

    @Test func anUnknownFontKeyFallsBackToTheRecommendedOne() {
        #expect(ProjectionFontFamily(apiValue: "inventada") == .system)
        #expect(ProjectionFontFamily(apiValue: "georgia") == .georgia)
    }

    // MARK: Settings screen

    private func loaded(settings: ProjectionSettings = ProjectionSettings(), session: SessionContext = .preview) -> ProjectionSettingsViewModel {
        let store = InMemoryChurchStore()
        store.projection = settings
        let viewModel = ProjectionSettingsViewModel(
            repository: MockProjectionSettingsRepository(store: store, latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            session: session
        )
        return viewModel
    }

    @Test func loadsWhatIsSavedAndShowsItInThePreview() async {
        let viewModel = loaded(settings: ProjectionSettings(fontFamily: .futura, fontSizePt: 64, defaultBackgroundId: "aurora"))
        await viewModel.load()
        #expect(viewModel.settings.fontFamily == .futura)
        #expect(viewModel.defaultBackground?.id == "aurora")
        #expect(viewModel.previewFrame.background?.id == "aurora")
        if case .text = viewModel.previewFrame.content {} else { Issue.record("La vista previa debe mostrar letra.") }
    }

    @Test func savingAFontFamilyPersistsImmediately() async throws {
        let store = InMemoryChurchStore()
        let viewModel = ProjectionSettingsViewModel(
            repository: MockProjectionSettingsRepository(store: store, latency: .zero),
            backgroundRepository: MockBackgroundRepository()
        )
        await viewModel.load()

        viewModel.selectFontFamily(.palatino)
        #expect(viewModel.settings.fontFamily == .palatino)
        await viewModel.saveTask?.value
        #expect(store.projection.fontFamily == .palatino)
    }

    @Test func fontSizeStepsByFourAndStaysInRange() async {
        let viewModel = loaded(settings: ProjectionSettings(fontSizePt: 198))
        await viewModel.load()

        viewModel.increaseFontSize()
        #expect(viewModel.settings.fontSizePt == 200)
        #expect(!viewModel.canIncreaseFontSize)

        viewModel.setFontSize(10)
        #expect(viewModel.settings.fontSizePt == 40)
        #expect(!viewModel.canDecreaseFontSize)
    }

    @Test func selectingNoneClearsTheDefaultBackground() async throws {
        let store = InMemoryChurchStore()
        store.projection = ProjectionSettings(defaultBackgroundId: "aurora")
        let viewModel = ProjectionSettingsViewModel(
            repository: MockProjectionSettingsRepository(store: store, latency: .zero),
            backgroundRepository: MockBackgroundRepository()
        )
        await viewModel.load()

        viewModel.selectDefaultBackground(nil)
        await viewModel.saveTask?.value
        #expect(store.projection.defaultBackgroundId == nil)
    }

    @Test func withoutPermissionNothingChangesAndNothingSaves() async {
        let viewModel = loaded(session: .preview(role: .operator))
        await viewModel.load()
        let before = viewModel.settings

        viewModel.selectFontFamily(.georgia)
        viewModel.setFontSize(120)
        viewModel.selectDefaultBackground("aurora")

        #expect(viewModel.settings == before)
        #expect(viewModel.saveTask == nil)
    }

    @Test func aFailedSaveRevertsAndExplains() async {
        struct FailingProjectionSettings: ProjectionSettingsRepository {
            func settings() async throws -> ProjectionSettings { ProjectionSettings() }
            func save(_ settings: ProjectionSettings) async throws { throw URLError(.notConnectedToInternet) }
        }
        let viewModel = ProjectionSettingsViewModel(repository: FailingProjectionSettings(), backgroundRepository: MockBackgroundRepository())
        await viewModel.load()

        viewModel.selectFontFamily(.optima)
        await viewModel.saveTask?.value

        #expect(viewModel.settings.fontFamily == .system)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: A new service

    @Test func aNewServiceWithNoDefaultStartsOnBlackNotTheFirstGradient() async {
        let store = InMemoryChurchStore()
        let viewModel = LiveConsoleViewModel(
            session: .preview,
            serviceType: store.serviceTypes[0],
            modules: ChurchModules(),
            people: store.people,
            servicePlanRepository: MockServicePlanRepository(),
            projectionSettings: MockProjectionSettingsRepository(store: store, latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(latency: .zero),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: MockDisplayOutputService(),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            peopleRepository: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
        await viewModel.load()
        #expect(viewModel.selectedBackgroundID == nil)
        #expect(viewModel.liveFrame.background == nil)
    }

    @Test func aNewServiceOpensOnTheChurchsConfiguredBackground() async {
        let store = InMemoryChurchStore()
        store.projection = ProjectionSettings(defaultBackgroundId: "oceano")
        let viewModel = LiveConsoleViewModel(
            session: .preview,
            serviceType: store.serviceTypes[0],
            modules: ChurchModules(),
            people: store.people,
            servicePlanRepository: MockServicePlanRepository(),
            projectionSettings: MockProjectionSettingsRepository(store: store, latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(latency: .zero),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: MockDisplayOutputService(),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            peopleRepository: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
        await viewModel.load()
        #expect(viewModel.selectedBackgroundID == "oceano")
        #expect(viewModel.liveFrame.background?.id == "oceano")
    }

    @Test func pickingNingunoMidServiceGoesBackToBlack() async {
        let viewModel = LiveConsoleViewModel.preview
        viewModel.selectBackground("aurora")
        #expect(viewModel.liveFrame.background?.id == "aurora")

        viewModel.selectBackground(nil)
        #expect(viewModel.selectedBackgroundID == nil)
        #expect(viewModel.liveFrame.background == nil)
    }

    @Test func theConsolesTypographyReachesTheTVStore() async {
        let store = InMemoryChurchStore()
        store.projection = ProjectionSettings(fontFamily: .baskerville, fontSizePt: 120)
        let projection = ProjectionStore()
        let display = LiveDisplayOutputService(store: projection)
        let viewModel = LiveConsoleViewModel(
            session: .preview,
            serviceType: store.serviceTypes[0],
            modules: ChurchModules(),
            people: store.people,
            servicePlanRepository: MockServicePlanRepository(),
            projectionSettings: MockProjectionSettingsRepository(store: store, latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(latency: .zero),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: display,
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            peopleRepository: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
        await viewModel.load()
        #expect(projection.typography == ProjectionSettings(fontFamily: .baskerville, fontSizePt: 120))
    }

    // MARK: Font sizing math

    @Test func fontSizeScalesProportionallyToTheCanvasWidth() {
        let settings = ProjectionSettings(fontSizePt: 96)
        #expect(settings.bodyFont(width: 1920) == Font.system(size: 96, weight: .medium))
        #expect(settings.bodyFont(width: 960) == Font.system(size: 48, weight: .medium))
    }

    @Test func theDefaultSizeMatchesWhatTheFixedRatioUsedToDraw() {
        // Before this feature, body text was always `width * 0.046`; a church that never opens
        // Proyección must see (as near as makes no difference) the same size as before.
        let settings = ProjectionSettings()
        let old = 1920 * 0.046
        let new: CGFloat = 1920 / 1920 * CGFloat(settings.fontSizePt)
        #expect(abs(new - old) < 1)
    }
}
