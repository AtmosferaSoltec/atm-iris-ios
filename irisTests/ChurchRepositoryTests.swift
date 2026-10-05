//
//  ChurchRepositoryTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// The mock church repositories share one in-memory store and follow the agreed data rules.
struct ChurchRepositoryTests {
    private let store = InMemoryChurchStore()

    private var modules: MockModuleSettingsRepository { MockModuleSettingsRepository(store: store, latency: .zero) }
    private var serviceTypes: MockServiceTypeRepository { MockServiceTypeRepository(store: store, latency: .zero) }
    private var people: MockPeopleRepository { MockPeopleRepository(store: store, latency: .zero) }
    private var records: MockTimeRecordRepository { MockTimeRecordRepository(store: store, latency: .zero) }

    @Test func changesAreVisibleThroughAnotherRepositoryInstance() async throws {
        var updated = try await modules.modules()
        updated.timeControl = false
        try await modules.save(updated)

        let other = MockModuleSettingsRepository(store: store, latency: .zero)
        #expect(try await other.modules().timeControl == false)
    }

    @Test func savingAServiceTypeReplacesByIDOrAppends() async throws {
        var culto = try #require(try await serviceTypes.serviceTypes().first)
        culto.name = "Culto dominical"
        try await serviceTypes.save(culto)
        try await serviceTypes.save(ServiceType(name: "Oración", color: 0x4E5BFF, schedule: nil))

        let saved = try await serviceTypes.serviceTypes()
        #expect(saved.count == MockChurchData.serviceTypes.count + 1)
        #expect(saved.first?.name == "Culto dominical")
        #expect(saved.last?.name == "Oración")
    }

    @Test func deletingAServiceTypeKeepsItsRecords() async throws {
        let culto = try #require(try await serviceTypes.serviceTypes().first)
        try await serviceTypes.delete(culto.id)

        #expect(try await serviceTypes.serviceTypes().contains { $0.id == culto.id } == false)
        #expect(try await records.records().contains { $0.serviceTypeID == culto.id })
    }

    @Test func addingAndRenamingPeople() async throws {
        let added = try await people.add(name: "Rut Salas")
        try await people.rename(added.id, to: "Rut Salas Vega")

        #expect(try await people.people().last == Person(id: added.id, name: "Rut Salas Vega"))
    }

    @Test func deletingAPersonClearsTemplateDefaultsButKeepsRecords() async throws {
        let daniel = try #require(try await people.people().first { $0.name == "Daniel Ruiz" })
        try await people.delete(daniel.id)

        let blocks = try await serviceTypes.serviceTypes().flatMap(\.blocks)
        #expect(blocks.contains { $0.defaultPersonID == daniel.id } == false)
        #expect(blocks.first { $0.name == "Prédica" }?.defaultPersonID == nil)

        let recordBlocks = try await records.records().flatMap(\.blocks).filter { $0.personID == daniel.id }
        #expect(recordBlocks.isEmpty == false)
        #expect(recordBlocks.allSatisfy { $0.personName == "Daniel Ruiz" })
    }

    @Test func recordShowsCurrentNameThenSavedName() async throws {
        let ana = try #require(try await people.people().first { $0.name == "Ana Torres" })
        let block = try #require(try await records.records().flatMap(\.blocks).first { $0.personID == ana.id })

        try await people.rename(ana.id, to: "Ana Torres de León")
        #expect(block.resolvedPersonName(in: try await people.people()) == "Ana Torres de León")

        try await people.delete(ana.id)
        #expect(block.resolvedPersonName(in: try await people.people()) == "Ana Torres")

        let unassigned = BlockRecord(name: "Anuncios", plannedSeconds: 300, actualSeconds: 280, personID: nil)
        #expect(unassigned.resolvedPersonName(in: try await people.people()) == nil)
    }

    @Test func recordsStayNewestFirstAndReplaceByID() async throws {
        let culto = try #require(MockChurchData.serviceTypes.first)
        let newest = ServiceRecord(date: .now.addingTimeInterval(3600), serviceTypeID: culto.id, blocks: [])
        let oldest = ServiceRecord(date: .distantPast, serviceTypeID: culto.id, blocks: [])
        try await records.save(oldest)
        try await records.save(newest)

        var edited = newest
        edited.blocks = [BlockRecord(name: "Prédica", plannedSeconds: 2400, actualSeconds: 2460, personID: nil, status: .adjusted)]
        try await records.save(edited)

        let saved = try await records.records()
        #expect(saved.count == MockChurchData.records.count + 2)
        #expect(saved.first == edited)
        #expect(saved.last == oldest)
        #expect(saved.map(\.date) == saved.map(\.date).sorted(by: >))
    }

    @Test func deletingARecord() async throws {
        let first = try #require(try await records.records().first)
        try await records.delete(first.id)

        #expect(try await records.records().contains { $0.id == first.id } == false)
    }
}
