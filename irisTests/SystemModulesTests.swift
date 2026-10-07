//
//  SystemModulesTests.swift
//  irisTests
//
//  Modules switched off for all of Iris (`availableModules`, contract §6): today the Bible.
//  They are not offered anywhere, and saving the other switches never changes them.
//

import Foundation
import Testing
@testable import iris

@MainActor
struct SystemModulesTests {
    /// The church as the API sends it with the Bible switched off for everyone.
    private static let churchWithoutBible = """
    {"id":"\(ContractSamples.churchID)","name":"Iglesia Vida Nueva","timezone":"America/Lima",
    "modules":{"bible":false,"multimedia":true,"timeControl":true},
    "availableModules":{"bible":false,"multimedia":true,"timeControl":true},
    "storage":{"usedBytes":0,"quotaBytes":5368709120},"createdAt":"2026-10-01T10:00:00.000Z","updatedAt":"2026-10-07T10:00:00.000Z"}
    """

    private func withoutBible() -> InMemoryChurchStore {
        let store = InMemoryChurchStore()
        store.availableModules = ChurchModules(bible: false, multimedia: true, timeControl: true)
        store.modules = ChurchModules(bible: false, multimedia: true, timeControl: true)
        return store
    }

    // MARK: Contract

    @Test func decodesTheModulesThatExistInIris() throws {
        let church = try JSONCoding.decoder.decode(ChurchDTO.self, from: Data(Self.churchWithoutBible.utf8))
        #expect(church.availableModules.map(ChurchModules.init) == ChurchModules(bible: false, multimedia: true, timeControl: true))
        #expect(ChurchModules(church.modules).bible == false)
    }

    @Test func anOlderServerWithoutTheFieldOffersEverything() throws {
        let church = try JSONCoding.decoder.decode(ChurchDTO.self, from: Data(ContractSamples.church.utf8))
        #expect(church.availableModules == nil)
    }

    // MARK: Módulos screen

    @Test func theBibleIsNotListedWhileSwitchedOffForEveryone() async {
        let viewModel = ModulesViewModel(moduleSettings: MockModuleSettingsRepository(store: withoutBible(), latency: .zero))
        await viewModel.load()
        #expect(viewModel.visibleModules == [.lyrics, .multimedia, .timeControl])
    }

    @Test func everythingIsListedWhenIrisOffersEverything() async {
        let viewModel = ModulesViewModel(moduleSettings: MockModuleSettingsRepository(store: InMemoryChurchStore(), latency: .zero))
        await viewModel.load()
        #expect(viewModel.visibleModules == ModulesViewModel.Module.allCases)
    }

    // MARK: Home and console

    @Test func homeKnowsTheBibleIsNotOfferedAndTheConsoleHidesIt() async throws {
        let store = withoutBible()
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
        await home.load()
        #expect(home.availableModules.bible == false)
        #expect(home.modules.bible == false)

        let console = LiveConsoleViewModel(
            session: .preview,
            serviceType: store.serviceTypes.first,
            modules: home.modules,
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
        #expect(console.showsBible == false)
        console.presentBible()
        #expect(console.biblePicker == nil)
    }

    // MARK: Live copy

    @Test func theSyncedChurchSaysTheBibleIsOffAndSavingKeepsIt() async throws {
        let stack = try LiveStack { request in
            switch (request.method, request.path) {
            case ("GET", "/sync/changes"):
                .data(ContractSamples.syncPage(church: Self.churchWithoutBible, cursor: "3", hasMore: false))
            case ("PUT", "/church/modules"):
                .data(Self.churchWithoutBible)
            default:
                .error(404, code: "NOT_FOUND")
            }
        }
        await stack.sync.start(session: LiveStack.session)
        let settings = LiveModuleSettingsRepository(data: stack.data)

        #expect(await settings.availableModules().bible == false)
        #expect(try await settings.modules().bible == false)

        // Turning time control off sends the Bible as it is, and the local copy keeps knowing it is off.
        try await settings.save(ChurchModules(bible: false, multimedia: true, timeControl: false))
        #expect(await settings.availableModules().bible == false)
    }
}
