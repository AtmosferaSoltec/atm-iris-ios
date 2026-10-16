//
//  HomeViewModelTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// Home navigates from its tiles and reflects changes made on other screens.
struct HomeViewModelTests {
    /// Collects the routes Home asks for.
    private final class RouteLog {
        var routes: [SignedInNavigator.Route] = []
    }

    private let log = RouteLog()

    private func makeViewModel(store: InMemoryChurchStore) -> HomeViewModel {
        let log = log
        return HomeViewModel(
            session: .preview,
            moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero),
            libraryRepository: MockLibraryRepository(latency: .zero),
            displayOutput: MockDisplayOutputService(),
            onNavigate: { log.routes.append($0) }
        )
    }

    @Test func tilesAndHeroNavigate() async throws {
        let viewModel = makeViewModel(store: InMemoryChurchStore())
        await viewModel.appear()

        viewModel.openServices()
        viewModel.openTimes()
        viewModel.openPeople()
        viewModel.openModules()
        let selected = try #require(viewModel.selectedServiceType)
        await viewModel.startSelectedService()

        #expect(log.routes == [.services, .times, .people, .modules, .console(selected)])
    }

    @Test func timesAndPeopleRequireTimeControl() async {
        let store = InMemoryChurchStore()
        store.modules.timeControl = false
        let viewModel = makeViewModel(store: store)
        await viewModel.appear()

        viewModel.openTimes()
        viewModel.openPeople()

        #expect(log.routes.isEmpty)
    }

    @Test func timesSubtitleCountsRecords() async throws {
        let store = InMemoryChurchStore(seed: .empty)
        let viewModel = makeViewModel(store: store)
        await viewModel.appear()
        #expect(viewModel.timesSubtitle == "Aún no hay registros")

        let records = MockTimeRecordRepository(store: store, latency: .zero)
        try await records.save(ServiceRecord(date: .now, serviceTypeID: UUID(), blocks: []))
        await viewModel.appear()
        #expect(viewModel.timesSubtitle == "1 servicio registrado")

        try await records.save(ServiceRecord(date: .now, serviceTypeID: UUID(), blocks: []))
        await viewModel.appear()
        #expect(viewModel.timesSubtitle == "2 servicios registrados")
    }

    @Test func reappearingShowsChangesAndKeepsTheSelection() async throws {
        let store = InMemoryChurchStore()
        let viewModel = makeViewModel(store: store)
        await viewModel.appear()
        let youth = try #require(viewModel.serviceTypes.first { $0.name == "Jóvenes" })
        viewModel.selectServiceType(youth.id)

        // Edits another screen would make.
        var renamed = youth
        renamed.name = "Jóvenes en acción"
        try await MockServiceTypeRepository(store: store, latency: .zero).save(renamed)
        _ = try await MockPeopleRepository(store: store, latency: .zero).add(name: "Rut Salas")
        try await MockTimeRecordRepository(store: store, latency: .zero)
            .save(ServiceRecord(date: .now, serviceTypeID: youth.id, blocks: []))
        var modules = store.modules
        modules.bible = false
        try await MockModuleSettingsRepository(store: store, latency: .zero).save(modules)

        await viewModel.appear()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.selectedServiceTypeID == youth.id)
        #expect(viewModel.selectedServiceType?.name == "Jóvenes en acción")
        #expect(viewModel.people.count == MockChurchData.people.count + 1)
        #expect(viewModel.recordCount == MockChurchData.records.count + 1)
        #expect(viewModel.modules.bible == false)
    }

    @Test func deletingTheSelectedTypeFallsBackToASuggestion() async throws {
        let store = InMemoryChurchStore()
        let viewModel = makeViewModel(store: store)
        await viewModel.appear()
        let youth = try #require(viewModel.serviceTypes.first { $0.name == "Jóvenes" })
        viewModel.selectServiceType(youth.id)

        try await MockServiceTypeRepository(store: store, latency: .zero).delete(youth.id)
        await viewModel.appear()

        #expect(viewModel.selectedServiceType != nil)
        #expect(viewModel.selectedServiceTypeID != youth.id)
    }

    @Test func emptyChurchInvitesToConfigureServices() async {
        let viewModel = makeViewModel(store: InMemoryChurchStore(seed: .empty))
        await viewModel.appear()

        #expect(viewModel.needsServiceSetup)
        #expect(viewModel.selectedServiceType == nil)

        await viewModel.startSelectedService()
        viewModel.openServices()
        #expect(log.routes == [.services])
    }

    /// Records what the sync was asked, and can take forever (a church WiFi that is down).
    private final class ScriptedSync: SyncService {
        var status: SyncStatus = .idle(lastSync: nil)
        var initialSync: InitialSyncState = .ready
        var pendingCount = 0
        var notice: String?
        var storageWarning: String?
        var reasons: [SyncReason] = []
        var neverFinishes = false
        let log: RouteLog

        init(log: RouteLog) { self.log = log }

        func start(session: UserSession) async {}
        func syncNow(reason: SyncReason) async {
            reasons.append(reason)
            if neverFinishes { try? await Task.sleep(for: .seconds(60)) }
        }
        func flushSoon() {}
        func suspend() {}
        func resume() {}
        func dismissNotice() {}
        func discardLocalData() async {}
    }

    private func makeViewModel(store: InMemoryChurchStore, sync: any SyncService) -> HomeViewModel {
        let log = log
        return HomeViewModel(
            session: .preview,
            moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero),
            libraryRepository: MockLibraryRepository(latency: .zero),
            displayOutput: MockDisplayOutputService(),
            sync: sync,
            onNavigate: { log.routes.append($0) }
        )
    }

    @Test func startingAServiceFirstCatchesUpWithTheWeb() async throws {
        let sync = ScriptedSync(log: log)
        let viewModel = makeViewModel(store: InMemoryChurchStore(), sync: sync)
        await viewModel.appear()
        sync.reasons.removeAll()

        await viewModel.startSelectedService()

        #expect(sync.reasons == [.beforeService])
        #expect(log.routes.count == 1)
    }

    @Test func startingAServiceDoesNotWaitForeverWithoutConnection() async throws {
        let sync = ScriptedSync(log: log)
        sync.neverFinishes = true
        let viewModel = makeViewModel(store: InMemoryChurchStore(), sync: sync)
        await viewModel.appear()

        let started = ContinuousClock.now
        await viewModel.startSelectedService()

        #expect(ContinuousClock.now - started < .seconds(8))
        #expect(log.routes.count == 1)
    }
}
