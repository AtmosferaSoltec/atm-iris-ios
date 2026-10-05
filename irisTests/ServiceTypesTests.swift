//
//  ServiceTypesTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// Servicios: list texts, and the editor's draft, validation, blocks and persistence.
struct ServiceTypesTests {
    private let store = InMemoryChurchStore()

    private func makeList() async -> ServiceTypesViewModel {
        let viewModel = ServiceTypesViewModel(
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero)
        )
        await viewModel.load()
        return viewModel
    }

    private func culto(in list: ServiceTypesViewModel) throws -> ServiceType {
        try #require(list.serviceTypes.first { $0.name == "Culto general" })
    }

    // MARK: List

    @Test func listDescribesEachType() async throws {
        let list = await makeList()
        let culto = try culto(in: list)
        let youth = try #require(list.serviceTypes.first { $0.name == "Jóvenes" })

        #expect(list.scheduleText(for: culto) == "Domingo · 10:00")
        #expect(list.scheduleText(for: youth) == "Sábado · 19:00")
        #expect(list.showsBlocks(of: culto))
        #expect(list.showsBlocks(of: youth) == false)
        #expect(list.blocksSummary(for: culto).hasPrefix("4 bloques · "))
    }

    @Test func blocksStayHiddenWithoutTimeControl() async throws {
        store.modules.timeControl = false
        let list = await makeList()

        #expect(list.showsBlocks(of: try culto(in: list)) == false)
    }

    // MARK: Creating

    @Test func newServiceNeedsAUniqueName() async throws {
        let list = await makeList()
        list.createServiceType()
        let editor = try #require(list.editor)

        #expect(editor.isNew)
        #expect(editor.canSave == false)

        editor.name = " culto GENERAL "
        #expect(editor.nameError == "Ya existe un servicio con ese nombre.")
        #expect(editor.canSave == false)

        editor.name = "Oración"
        #expect(editor.nameError == nil)
        #expect(editor.canSave)
    }

    @Test func creatingAServiceWithScheduleAndBlocks() async throws {
        let list = await makeList()
        list.createServiceType()
        let editor = try #require(list.editor)
        await editor.load()

        editor.name = "  Oración "
        editor.color = ServiceType.palette[3]
        editor.hasSchedule = true
        editor.weekday = 4
        editor.scheduleTime = try #require(Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: .now))

        editor.setTracksTime(true)
        #expect(editor.blocks.count == 1)
        let first = try #require(editor.blocks.first)
        #expect(first.name == "Nuevo bloque")
        #expect(first.plannedMinutes == 10)
        editor.renameBlock(first.id, to: " Intercesión ")
        editor.setMinutes(300, of: first.id)
        #expect(editor.blocks.first?.plannedMinutes == 240)

        editor.addBlock()
        let second = try #require(editor.blocks.last)
        let ana = try #require(editor.people.first { $0.name == "Ana Torres" })
        editor.setPerson(ana.id, for: second.id)
        editor.moveBlocks([second.id], before: first.id)

        await editor.save()

        let saved = try #require(store.serviceTypes.first { $0.name == "Oración" })
        #expect(saved.color == ServiceType.palette[3])
        #expect(saved.schedule == ServiceType.Schedule(weekday: 4, hour: 19, minute: 30))
        #expect(saved.blocks.map(\.name) == ["Nuevo bloque", "Intercesión"])
        #expect(saved.blocks.map(\.plannedMinutes) == [10, 240])
        #expect(saved.blocks.first?.defaultPersonID == ana.id)
        #expect(list.editor == nil)
        #expect(list.serviceTypes.last == saved)
    }

    // MARK: Editing

    @Test func theDraftIsOnlySavedOnSave() async throws {
        let list = await makeList()
        let culto = try culto(in: list)
        list.edit(culto)
        let editor = try #require(list.editor)

        editor.name = "Otro nombre"
        editor.removeBlock(try #require(editor.blocks.first).id)

        #expect(store.serviceTypes.first { $0.id == culto.id } == culto)
    }

    @Test func turningTimeControlOffAsksBeforeDroppingBlocks() async throws {
        let list = await makeList()
        let culto = try culto(in: list)
        list.edit(culto)
        let editor = try #require(list.editor)

        editor.setTracksTime(false)
        #expect(editor.isConfirmingBlockRemoval)
        #expect(editor.tracksTime)
        #expect(editor.blocks.count == 4)

        editor.confirmBlockRemoval()
        #expect(editor.tracksTime == false)
        await editor.save()

        #expect(store.serviceTypes.first { $0.id == culto.id }?.tracksTime == false)
        #expect(list.serviceTypes.first { $0.id == culto.id }?.tracksTime == false)
    }

    @Test func blocksMustHaveNamesAndAtLeastOneExists() async throws {
        let list = await makeList()
        list.edit(try culto(in: list))
        let editor = try #require(list.editor)
        let first = try #require(editor.blocks.first)

        editor.renameBlock(first.id, to: "  ")
        #expect(editor.isBlockNameMissing(first.id))
        #expect(editor.canSave == false)

        for block in editor.blocks { editor.removeBlock(block.id) }
        #expect(editor.blocksError == "Agrega al menos un bloque o desactiva el control de tiempo.")
        #expect(editor.canSave == false)
    }

    @Test func withoutTheModuleBlocksAreKeptUntouched() async throws {
        store.modules.timeControl = false
        let list = await makeList()
        let culto = try culto(in: list)
        list.edit(culto)
        let editor = try #require(list.editor)

        #expect(editor.showsTimeControl == false)
        editor.name = "Culto dominical"
        await editor.save()

        #expect(store.serviceTypes.first { $0.id == culto.id }?.blocks == culto.blocks)
    }

    @Test func addingALeaderFromTheEditor() async throws {
        let list = await makeList()
        list.edit(try culto(in: list))
        let editor = try #require(list.editor)
        await editor.load()
        let block = try #require(editor.blocks.last)

        editor.beginAddPerson(for: block.id)
        #expect(editor.isAddingPerson)
        editor.newPersonName = "Rut Salas"
        editor.isAddingPerson = false // the alert closes before its action runs
        await editor.confirmAddPerson()
        let rut = try #require(store.people.first { $0.name == "Rut Salas" })
        #expect(editor.blocks.last?.defaultPersonID == rut.id)

        editor.beginAddPerson(for: block.id)
        editor.newPersonName = "daniel ruiz"
        await editor.confirmAddPerson()
        #expect(store.people.count == MockChurchData.people.count + 1)
        #expect(editor.personName(editor.blocks.last?.defaultPersonID) == "Daniel Ruiz")
    }

    // MARK: Deleting

    @Test func deletingAServiceKeepsItsTimes() async throws {
        let list = await makeList()
        let culto = try culto(in: list)
        list.edit(culto)
        let editor = try #require(list.editor)

        editor.requestDelete()
        #expect(editor.isConfirmingDeletion)
        await editor.delete()

        #expect(store.serviceTypes.contains { $0.id == culto.id } == false)
        #expect(list.serviceTypes.contains { $0.id == culto.id } == false)
        #expect(list.editor == nil)
        #expect(store.records.contains { $0.serviceTypeID == culto.id })
    }

    // MARK: Home

    @Test func homeReflectsTheChanges() async throws {
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

        let list = await makeList()
        list.createServiceType()
        let editor = try #require(list.editor)
        editor.name = "Oración"
        await editor.save()

        let people = PeopleViewModel(
            people: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
        await people.load()
        people.newName = "Rut Salas"
        await people.add()

        await home.appear()
        #expect(home.serviceTypes.map(\.name) == ["Culto general", "Jóvenes", "ABC", "Oración"])
        #expect(home.people.count == MockChurchData.people.count + 1)
    }
}
