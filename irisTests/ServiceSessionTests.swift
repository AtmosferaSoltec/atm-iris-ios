//
//  ServiceSessionTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// Starting a service from Home (empty console) and timing its blocks until the record is saved.
struct ServiceSessionTests {
    /// Time the console sees; tests move it forward by hand.
    private final class TestClock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        func advance(minutes: Int, seconds: Int = 0) { now.addTimeInterval(TimeInterval(minutes * 60 + seconds)) }
    }

    private let store = InMemoryChurchStore()
    private let clock = TestClock()

    private var culto: ServiceType { store.serviceTypes[0] }

    private func console(serviceType: ServiceType?, modules: ChurchModules = ChurchModules()) -> LiveConsoleViewModel {
        let clock = clock
        return LiveConsoleViewModel(
            session: .preview,
            serviceType: serviceType,
            modules: modules,
            people: store.people,
            servicePlanRepository: EmptyServicePlanRepository(now: { clock.now }),
            projectionSettings: MockProjectionSettingsRepository(store: store, latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(latency: .zero),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: MockDisplayOutputService(),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            peopleRepository: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero),
            clock: { clock.now }
        )
    }

    private func person(_ name: String) throws -> Person.ID {
        try #require(store.people.first { $0.name == name }).id
    }

    /// Confirms the leader the picker suggests.
    private func confirmSuggested(_ viewModel: LiveConsoleViewModel) throws {
        let picker = try #require(viewModel.responsiblePicker)
        picker.confirm()
        #expect(viewModel.responsiblePicker == nil)
    }

    // MARK: Phase 6

    @Test func startingAServiceOpensAnEmptyConsole() async {
        let viewModel = console(serviceType: culto)
        await viewModel.load()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.serviceTitle == "Culto general")
        #expect(viewModel.selectedItemID == nil)
        #expect(viewModel.liveFrame.content == .blank)
        // Nothing configured in Proyección: a new service opens on black, not the first gradient.
        #expect(viewModel.selectedBackground == nil)
        #expect(viewModel.service?.date == clock.now)
    }

    @Test func addingToAStartedServiceStillWorks() async throws {
        let viewModel = console(serviceType: culto)
        await viewModel.load()
        viewModel.presentAddToService()
        let sheet = try #require(viewModel.addSheet)
        await sheet.load()
        let first = try #require(sheet.lyrics.first)

        sheet.toggle(.lyric(first.id))
        sheet.confirm()

        #expect(viewModel.items.map(\.title) == [first.title])
        #expect(viewModel.selectedItemID == viewModel.items.first?.id)
    }

    @Test func timerOnlyWithTimeControlAndBlocks() {
        #expect(console(serviceType: culto).showsBlockTimer)
        #expect(console(serviceType: store.serviceTypes[1]).showsBlockTimer == false)
        #expect(console(serviceType: culto, modules: ChurchModules(bible: true, multimedia: true, timeControl: false)).showsBlockTimer == false)
        #expect(console(serviceType: nil).showsBlockTimer == false)
    }

    // MARK: Phase 7

    @Test func fullFlowSavesTheRecord() async throws {
        let viewModel = console(serviceType: culto)
        await viewModel.load()
        #expect(viewModel.blocksSummaryText.hasPrefix("4 bloques · "))
        let start = clock.now

        viewModel.startBlocks()
        let firstPicker = try #require(viewModel.responsiblePicker)
        #expect(firstPicker.blockName == "Bienvenida")
        #expect(firstPicker.selectedPersonID == (try person("Carlos Pérez")))
        #expect(firstPicker.people.first?.name == "Carlos Pérez")
        try confirmSuggested(viewModel)
        #expect(viewModel.isTimerRunning)

        clock.advance(minutes: 9, seconds: 41)
        viewModel.goToNextBlock()
        try confirmSuggested(viewModel)
        #expect(viewModel.currentBlock?.name == "Alabanzas")

        clock.advance(minutes: 19, seconds: 6)
        viewModel.goToNextBlock()
        try confirmSuggested(viewModel)
        clock.advance(minutes: 51, seconds: 31)
        viewModel.goToNextBlock()
        try confirmSuggested(viewModel)
        #expect(viewModel.isOnLastBlock)

        clock.advance(minutes: 5, seconds: 56)
        viewModel.goToNextBlock()
        #expect(viewModel.isConfirmingFinish)
        await viewModel.finishService()

        #expect(viewModel.isRecordSaved)
        #expect(viewModel.isAskingTemplateUpdate == false)
        let saved = try #require(store.records.first { $0.id == viewModel.finishedRecord?.id })
        #expect(store.records.count == MockChurchData.records.count + 1)
        #expect(saved.date == start)
        #expect(saved.serviceTypeID == culto.id)
        #expect(saved.blocks.map(\.actualSeconds) == [581, 1_146, 3_091, 356])
        #expect(saved.blocks.map(\.personName) == ["Carlos Pérez", "Ana Torres", "Daniel Ruiz", "Lucía Gómez"])
        #expect(viewModel.finishedSummary == "Servicio terminado · 1:26:14 (previsto 1:10:00 · +16:14)")
    }

    @Test func clockShowsRemainingThenOvertimeWithoutMargin() throws {
        let viewModel = console(serviceType: culto)
        viewModel.startBlocks()
        try confirmSuggested(viewModel)

        clock.advance(minutes: 8)
        viewModel.apply(blockTimer: try #require(viewModel.blockTimer), now: clock.now)
        #expect(viewModel.currentDeltaText == "−2:00")
        #expect(viewModel.currentClockState == .normal)

        clock.advance(minutes: 2, seconds: 1)
        viewModel.apply(blockTimer: try #require(viewModel.blockTimer), now: clock.now)
        #expect(viewModel.currentDeltaText == "+0:01")
        #expect(viewModel.currentClockState == .over)
        #expect(viewModel.currentProgress == 1)
    }

    @Test func changesTodayCanUpdateTheTemplate() async throws {
        let viewModel = console(serviceType: culto)
        viewModel.startBlocks()
        try confirmSuggested(viewModel)

        viewModel.presentAddBlock()
        let addSheet = try #require(viewModel.addBlockSheet)
        addSheet.name = " Santa Cena "
        addSheet.minutes = 12
        addSheet.add()
        #expect(viewModel.addBlockSheet == nil)
        #expect(viewModel.breadcrumbs.map(\.name) == ["Bienvenida", "Santa Cena", "Alabanzas", "Prédica", "Anuncios"])

        clock.advance(minutes: 10)
        viewModel.goToNextBlock()
        try confirmSuggested(viewModel)
        let anuncios = try #require(viewModel.pendingBlocks.last)
        viewModel.toggleSkip(anuncios.id)

        clock.advance(minutes: 12)
        viewModel.requestFinish()
        await viewModel.finishService()
        #expect(viewModel.isAskingTemplateUpdate)
        #expect(viewModel.isRecordSaved == false)
        #expect(viewModel.templateChangesMessage == "Agregaste Santa Cena y omitiste Anuncios.")

        await viewModel.saveRecord(updatingTemplate: true)
        #expect(viewModel.isRecordSaved)
        #expect(store.serviceTypes[0].blocks.map(\.name) == ["Bienvenida", "Santa Cena", "Alabanzas", "Prédica"])
        let saved = try #require(store.records.first { $0.id == viewModel.finishedRecord?.id })
        #expect(saved.blocks.map(\.status) == [.completed, .completed, .skipped, .skipped, .skipped])
        #expect(saved.blocks.map(\.actualSeconds) == [600, 720, 0, 0, 0])
    }

    @Test func onlyTodayKeepsTheTemplate() async throws {
        let viewModel = console(serviceType: culto)
        viewModel.startBlocks()
        try confirmSuggested(viewModel)
        viewModel.skipNextBlock()
        #expect(viewModel.breadcrumbs[1].state == .skipped)

        await viewModel.finishService()
        #expect(viewModel.isAskingTemplateUpdate)
        await viewModel.saveRecord(updatingTemplate: false)

        #expect(store.serviceTypes[0].blocks == culto.blocks)
        #expect(store.records.count == MockChurchData.records.count + 1)
    }

    @Test func pendingBlocksCanBeEdited() throws {
        let viewModel = console(serviceType: culto)
        viewModel.startBlocks()
        try confirmSuggested(viewModel)
        let pending = viewModel.pendingBlocks
        #expect(pending.map(\.name) == ["Alabanzas", "Prédica", "Anuncios"])

        viewModel.movePendingBlocks([pending[2].id], before: pending[0].id)
        viewModel.renamePendingBlock(pending[1].id, to: "Mensaje")
        viewModel.setPendingMinutes(500, of: pending[1].id)
        viewModel.setPendingLeader(nil, of: pending[1].id)

        #expect(viewModel.pendingBlocks.map(\.name) == ["Anuncios", "Alabanzas", "Mensaje"])
        #expect(viewModel.pendingBlocks.last?.plannedMinutes == 240)
        #expect(viewModel.pendingBlocks.last?.personID == nil)
    }

    @Test func addingALeaderFromThePicker() async throws {
        let viewModel = console(serviceType: culto)
        viewModel.startBlocks()
        let picker = try #require(viewModel.responsiblePicker)

        picker.newName = "Rut Salas"
        await picker.addPerson()
        let rut = try #require(store.people.first { $0.name == "Rut Salas" })
        #expect(picker.selectedPersonID == rut.id)
        #expect(viewModel.people.contains(rut))

        picker.newName = "carlos perez"
        await picker.addPerson()
        #expect(picker.selectedPersonID == (try person("Carlos Pérez")))
        #expect(store.people.count == MockChurchData.people.count + 1)

        picker.confirm()
        #expect(viewModel.currentBlock?.personID == (try person("Carlos Pérez")))
    }

    // MARK: Leaving

    @Test func leavingWhileRunningAsksFirst() async throws {
        let viewModel = console(serviceType: culto)
        viewModel.startBlocks()
        try confirmSuggested(viewModel)
        var exits = 0

        viewModel.requestExit { exits += 1 }
        #expect(viewModel.isConfirmingExit)
        #expect(exits == 0)

        viewModel.exitWithoutSaving()
        #expect(exits == 1)
        #expect(store.records.count == MockChurchData.records.count)
    }

    @Test func finishAndExitSavesThenLeaves() async throws {
        let viewModel = console(serviceType: culto)
        viewModel.startBlocks()
        try confirmSuggested(viewModel)
        clock.advance(minutes: 5)
        var exits = 0

        viewModel.requestExit { exits += 1 }
        await viewModel.finishAndExit()

        #expect(exits == 1)
        #expect(viewModel.isRecordSaved)
        #expect(store.records.count == MockChurchData.records.count + 1)
    }

    @Test func leavingWhenNotRunningIsImmediate() {
        let viewModel = console(serviceType: culto)
        var exits = 0
        viewModel.requestExit { exits += 1 }
        #expect(exits == 1)
        #expect(viewModel.isConfirmingExit == false)
    }
}

/// Music added before its file is on the iPad waits for the download, then plays the cached file.
@MainActor
struct CloudMusicTests {
    /// A library whose one track finishes downloading when the test says so.
    private final class DownloadingLibrary: LibraryRepository, @unchecked Sendable {
        var track = MediaAsset(id: "t1", kind: .music, title: "Preludio", subtitle: "", duration: "3:40", artwork: [0, 0], downloadState: .notDownloaded)
        private(set) var requested: [MediaAsset.ID] = []
        private var continuation: AsyncStream<Void>.Continuation?

        func lyrics() async throws -> [LyricSheet] { [] }
        func media(of kind: MediaAsset.Kind) async throws -> [MediaAsset] { kind == .music ? [track] : [] }
        func download(_ ids: [MediaAsset.ID]) async { requested += ids }
        func changes() -> AsyncStream<Void> {
            AsyncStream { self.continuation = $0 }
        }

        func finish(at url: URL) {
            track.downloadState = .ready
            track.localURL = url
            continuation?.yield()
        }
    }

    @Test func playsOnlyOnceTheFileIsHere() async throws {
        let store = InMemoryChurchStore()
        let library = DownloadingLibrary()
        let playback = MockMediaPlaybackService()
        let viewModel = LiveConsoleViewModel(
            session: .preview,
            serviceType: store.serviceTypes[0],
            modules: ChurchModules(),
            people: store.people,
            servicePlanRepository: EmptyServicePlanRepository(),
            projectionSettings: MockProjectionSettingsRepository(store: store, latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: library,
            mediaPlayback: playback,
            displayOutput: MockDisplayOutputService(),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            peopleRepository: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
        await viewModel.load()
        let observing = Task { await viewModel.observeLibrary() }
        defer { observing.cancel() }

        viewModel.appendToService([
            ServiceItem(kind: .music, title: "Preludio", subtitle: "", slides: [Slide(content: .audio(title: "Preludio", duration: "3:40"))], mediaID: "t1")
        ])
        #expect(viewModel.selectedMediaDownload == .notDownloaded)
        viewModel.presentSelectedMedia()
        #expect(viewModel.playback == nil)
        try await waitUntil { library.requested == ["t1"] }

        let file = URL.temporaryDirectory.appending(path: "preludio.mp3")
        library.finish(at: file)
        try await waitUntil { viewModel.selectedMediaDownload == .ready }
        #expect(viewModel.selectedItem?.slides.first?.content.url == file)
        viewModel.presentSelectedMedia()
        #expect(viewModel.playback?.title == "Preludio")
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }
}
