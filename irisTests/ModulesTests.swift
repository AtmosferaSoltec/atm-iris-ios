//
//  ModulesTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// Módulos saves each switch right away, and the console hides what is off.
struct ModulesTests {
    private struct SaveFailed: Error {}

    /// Loads fine but refuses every save.
    private struct FailingModuleSettings: ModuleSettingsRepository {
        func modules() async throws -> ChurchModules { ChurchModules() }
        func save(_ modules: ChurchModules) async throws { throw SaveFailed() }
    }

    // MARK: Módulos screen

    @Test func switchesAreSavedImmediately() async {
        let store = InMemoryChurchStore()
        let viewModel = ModulesViewModel(moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero))
        await viewModel.load()

        viewModel.setModule(.timeControl, isOn: false)
        #expect(viewModel.isOn(.timeControl) == false)
        #expect(viewModel.showsTimeControlNote)
        await viewModel.saveTask?.value
        #expect(store.modules.timeControl == false)

        viewModel.setModule(.multimedia, isOn: false)
        viewModel.setModule(.bible, isOn: false)
        await viewModel.saveTask?.value
        #expect(store.modules == ChurchModules(bible: false, multimedia: false, timeControl: false))
    }

    @Test func lyricsCannotBeTurnedOff() async {
        let viewModel = ModulesViewModel(moduleSettings: MockModuleSettingsRepository(store: InMemoryChurchStore(), latency: .zero))
        await viewModel.load()

        viewModel.setModule(.lyrics, isOn: false)

        #expect(viewModel.isOn(.lyrics))
        #expect(viewModel.saveTask == nil)
    }

    @Test func failedSaveRevertsTheSwitch() async {
        let viewModel = ModulesViewModel(moduleSettings: FailingModuleSettings())
        await viewModel.load()

        viewModel.setModule(.bible, isOn: false)
        await viewModel.saveTask?.value

        #expect(viewModel.isOn(.bible))
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: Console

    private func console(modules: ChurchModules) -> LiveConsoleViewModel {
        let viewModel = LiveConsoleViewModel(
            session: .preview,
            modules: modules,
            servicePlanRepository: MockServicePlanRepository(latency: .zero),
            projectionSettings: MockProjectionSettingsRepository(store: InMemoryChurchStore(), latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(latency: .zero),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: MockDisplayOutputService(),
            serviceTypes: MockServiceTypeRepository(store: InMemoryChurchStore(), latency: .zero),
            peopleRepository: MockPeopleRepository(store: InMemoryChurchStore(), latency: .zero),
            timeRecords: MockTimeRecordRepository(store: InMemoryChurchStore(), latency: .zero)
        )
        viewModel.apply(plan: MockServicePlanRepository.sample, backgrounds: MockBackgroundRepository.sample, display: nil)
        return viewModel
    }

    @Test func consoleWithEveryModuleOffersEverything() throws {
        let viewModel = console(modules: ChurchModules())

        #expect(viewModel.showsBible)
        viewModel.presentBible()
        #expect(viewModel.biblePicker != nil)

        viewModel.presentAddToService()
        #expect(viewModel.addSheet?.tabs == AddToServiceViewModel.Tab.allCases)

        let video = try #require(viewModel.items.first { $0.kind == .video })
        viewModel.selectItem(video.id)
        viewModel.presentSelectedMedia()
        #expect(viewModel.playback?.itemID == video.id)
    }

    @Test func consoleWithoutBibleHasNoPicker() {
        let viewModel = console(modules: ChurchModules(bible: false, multimedia: true, timeControl: true))

        #expect(viewModel.showsBible == false)
        viewModel.presentBible()
        #expect(viewModel.biblePicker == nil)
    }

    @Test func consoleWithoutMultimediaOnlyOffersLyrics() {
        let viewModel = console(modules: ChurchModules(bible: true, multimedia: false, timeControl: true))

        #expect(viewModel.showsMultimedia == false)
        #expect(viewModel.items.contains { [.music, .image, .video].contains($0.kind) } == false)
        #expect(viewModel.items.isEmpty == false)

        viewModel.presentAddToService()
        #expect(viewModel.addSheet?.tabs == [.lyrics])
        #expect(viewModel.addSheet?.tab == .lyrics)
        #expect(viewModel.addSheet?.isLyricsOnly == true)
    }

    @Test func homeHandsItsModulesToTheConsoleAfterRefresh() async throws {
        let store = InMemoryChurchStore()
        let home = HomeViewModel(
            session: .preview,
            moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero),
            libraryRepository: MockLibraryRepository(latency: .zero),
            displayOutput: MockDisplayOutputService(),
            onNavigate: { _ in }
        )
        await home.appear()

        let modulesScreen = ModulesViewModel(moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero))
        await modulesScreen.load()
        modulesScreen.setModule(.multimedia, isOn: false)
        await modulesScreen.saveTask?.value
        await home.appear()

        #expect(home.modules.multimedia == false)
        #expect(console(modules: home.modules).showsMultimedia == false)
    }
}
