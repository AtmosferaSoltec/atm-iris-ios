//
//  TimesViewModelTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// Tiempos: records by month, corrections that persist, deletion and summary texts.
struct TimesViewModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private let store: InMemoryChurchStore
    private let culto: ServiceType
    private let youth: ServiceType
    private let ana = Person(name: "Ana Torres")
    private let daniel = Person(name: "Daniel Ruiz")
    private let gone = UUID()

    init() {
        culto = ServiceType(name: "Culto general", color: 0xFFB547, schedule: nil)
        youth = ServiceType(name: "Jóvenes", color: 0xF0508C, schedule: nil)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        func day(_ month: Int, _ day: Int) -> Date { utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: 10))! }
        let records = [
            ServiceRecord(date: day(10, 4), serviceTypeID: culto.id, blocks: [
                BlockRecord(name: "Prédica", plannedSeconds: 2_400, actualSeconds: 2_700, personID: daniel.id, personName: "Daniel Ruiz"),
                BlockRecord(name: "Anuncios", plannedSeconds: 300, actualSeconds: 0, personID: nil, status: .skipped)
            ]),
            ServiceRecord(date: day(9, 27), serviceTypeID: youth.id, blocks: [
                BlockRecord(name: "Alabanzas", plannedSeconds: 900, actualSeconds: 880, personID: ana.id, personName: "Ana Torres")
            ]),
            ServiceRecord(date: day(9, 20), serviceTypeID: culto.id, blocks: [
                BlockRecord(name: "Prédica", plannedSeconds: 2_400, actualSeconds: 2_460, personID: gone, personName: "Pablo Castro")
            ])
        ]
        store = InMemoryChurchStore(seed: .init(modules: ChurchModules(), serviceTypes: [culto, youth], people: [ana, daniel], records: records))
    }

    private func makeViewModel() async -> TimesViewModel {
        let calendar = calendar
        let viewModel = TimesViewModel(
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            now: { calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12))! },
            calendar: calendar
        )
        await viewModel.load()
        return viewModel
    }

    // MARK: Records

    @Test func recordsAreGroupedByMonthNewestFirst() async {
        let viewModel = await makeViewModel()

        #expect(viewModel.recordSections.map(\.title) == ["OCTUBRE 2026", "SEPTIEMBRE 2026"])
        #expect(viewModel.recordSections.map(\.records.count) == [1, 2])
        #expect(viewModel.selectedRecord?.id == store.records.first?.id)
        #expect(viewModel.recordFilterTitle == "Todos los servicios")
    }

    @Test func quickFilterKeepsAValidSelection() async {
        let viewModel = await makeViewModel()

        viewModel.setRecordFilter(youth.id)
        #expect(viewModel.filteredRecords.count == 1)
        #expect(viewModel.selectedRecord?.serviceTypeID == youth.id)
        #expect(viewModel.recordFilterTitle == "Jóvenes")

        viewModel.setRecordFilter(nil)
        #expect(viewModel.filteredRecords.count == 3)
    }

    @Test func leaderNamesSurviveDeletedPeople() async throws {
        let viewModel = await makeViewModel()
        let blocks = viewModel.records.flatMap(\.blocks)

        #expect(viewModel.leaderName(of: try #require(blocks.first { $0.personID == daniel.id })) == "Daniel Ruiz")
        #expect(viewModel.leaderName(of: try #require(blocks.first { $0.personID == gone })) == "Pablo Castro")
        #expect(viewModel.leaderName(of: try #require(blocks.first { $0.personID == nil })) == "Sin responsable")
        let unnamed = BlockRecord(name: "X", plannedSeconds: 60, actualSeconds: 60, personID: UUID())
        #expect(viewModel.leaderName(of: unnamed) == "Persona eliminada")
        #expect(viewModel.serviceName(UUID()) == "Servicio eliminado")
    }

    @Test func adjustingADurationPersistsAsAdjusted() async throws {
        let viewModel = await makeViewModel()
        let record = try #require(viewModel.selectedRecord)
        let predica = try #require(record.blocks.first)

        viewModel.beginAdjustment(of: predica, in: record)
        let sheet = try #require(viewModel.adjustment)
        #expect(sheet.minutes == 45)
        #expect(sheet.seconds == 0)

        await viewModel.adjustDuration(of: predica.id, in: record.id, to: 2_430)

        let saved = try #require(store.records.first { $0.id == record.id }?.blocks.first)
        #expect(saved.actualSeconds == 2_430)
        #expect(saved.status == .adjusted)
        #expect(viewModel.selectedRecord?.blocks.first?.status == .adjusted)
    }

    @Test func changingTheLeaderPersists() async throws {
        let viewModel = await makeViewModel()
        let record = try #require(viewModel.selectedRecord)
        let predica = try #require(record.blocks.first)

        await viewModel.changeLeader(of: predica.id, in: record.id, to: ana.id)

        let saved = try #require(store.records.first { $0.id == record.id }?.blocks.first)
        #expect(saved.personID == ana.id)
        #expect(saved.personName == "Ana Torres")
        #expect(saved.status == .completed)
    }

    @Test func deletingTheSelectedRecord() async throws {
        let viewModel = await makeViewModel()
        let first = try #require(viewModel.selectedRecord)

        viewModel.requestDeleteSelected()
        #expect(viewModel.isConfirmingDeletion)
        await viewModel.deleteSelected()

        #expect(store.records.contains { $0.id == first.id } == false)
        #expect(viewModel.records.count == 2)
        #expect(viewModel.selectedRecord?.id == store.records.first?.id)
    }

    // MARK: Summaries

    @Test func summaryFiltersAndTexts() async {
        let viewModel = await makeViewModel()
        #expect(viewModel.periodTitle(viewModel.summaryFilter.period) == "Últimos 3 meses")
        #expect(viewModel.serviceCountText == "3")
        #expect(viewModel.overBlocksText.hasPrefix("2 de 3 · "))
        #expect(viewModel.overBlocksText.contains("67"))

        viewModel.setPeriod(.thisMonth)
        #expect(viewModel.serviceCountText == "1")
        #expect(viewModel.averageOvertimeText == "+5:00")

        viewModel.setPeriod(.lastMonth)
        viewModel.setServiceFilter(youth.id)
        #expect(viewModel.serviceFilterTitle == "Jóvenes")
        #expect(viewModel.averageOvertimeText == "a tiempo")

        viewModel.setServiceFilter(nil)
        viewModel.setBlockFilter("prédica")
        #expect(viewModel.blockFilterTitle == "prédica")
        #expect(viewModel.statistics.blockCount == 1)

        #expect(viewModel.blockNames == ["Alabanzas", "Anuncios", "Prédica"])
    }

    @Test func choosingAMonth() async {
        let viewModel = await makeViewModel()
        viewModel.beginPickingMonth()
        #expect(viewModel.isPickingMonth)
        viewModel.pickedYear = 2026
        viewModel.pickedMonth = 9
        viewModel.confirmPickedMonth()

        #expect(viewModel.summaryFilter.period == .month(year: 2026, month: 9))
        #expect(viewModel.periodTitle(viewModel.summaryFilter.period) == "Septiembre 2026")
        #expect(viewModel.serviceCountText == "2")
        #expect(viewModel.monthName(10) == "Octubre")
    }

    @Test func personDetailUsesNeutralWords() async {
        let viewModel = await makeViewModel()
        viewModel.setPeriod(.all)

        #expect(viewModel.personSummary(daniel.id) == "Se pasó en 1 de 1 bloques · promedio +5:00")
        #expect(viewModel.personSummary(ana.id) == "A tiempo en sus 1 bloques")
        viewModel.showPersonDetail(ana.id)
        #expect(viewModel.personDetail?.id == ana.id)
        #expect(viewModel.personStatistics(ana.id).entries.count == 1)
    }
}
