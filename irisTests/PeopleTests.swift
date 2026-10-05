//
//  PeopleTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// Personas: alphabetical list, block counts, and add/rename/delete with name validation.
struct PeopleTests {
    private let store = InMemoryChurchStore()

    private func makeViewModel() async -> PeopleViewModel {
        let viewModel = PeopleViewModel(
            people: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
        await viewModel.load()
        return viewModel
    }

    private func person(_ name: String, in viewModel: PeopleViewModel) throws -> Person {
        try #require(viewModel.people.first { $0.name == name })
    }

    @Test func listIsAlphabeticalWithBlockCounts() async throws {
        let viewModel = await makeViewModel()

        #expect(viewModel.people.map(\.name) == [
            "Ana Torres", "Carlos Pérez", "Daniel Ruiz", "José Herrera",
            "Lucía Gómez", "Marta Rivas", "Pablo Castro", "Sofía Méndez"
        ])
        #expect(viewModel.blockCountText(for: try person("Lucía Gómez", in: viewModel)) == "7 bloques")
        #expect(viewModel.blockCountText(for: try person("Marta Rivas", in: viewModel)) == "4 bloques")
        #expect(viewModel.blockCountText(for: try person("Sofía Méndez", in: viewModel)) == "1 bloque")
    }

    @Test func addingValidatesEmptyAndDuplicateNames() async {
        let viewModel = await makeViewModel()

        viewModel.newName = "   "
        await viewModel.add()
        #expect(viewModel.newNameError == "Escribe un nombre.")

        viewModel.newName = " ana TÓRRES "
        #expect(viewModel.newNameError == nil)
        await viewModel.add()
        #expect(viewModel.newNameError == "Ya existe una persona con ese nombre.")
        #expect(store.people.count == MockChurchData.people.count)
    }

    @Test func addingPersistsAndKeepsTheOrder() async throws {
        let viewModel = await makeViewModel()

        viewModel.newName = "  Beatriz Salas "
        await viewModel.add()

        #expect(viewModel.newName.isEmpty)
        #expect(viewModel.people.map(\.name).prefix(2) == ["Ana Torres", "Beatriz Salas"])
        #expect(viewModel.blockCountText(for: try #require(viewModel.people.first { $0.name == "Beatriz Salas" })) == "0 bloques")
        #expect(store.people.contains { $0.name == "Beatriz Salas" })
    }

    @Test func renamingValidatesAndPersists() async throws {
        let viewModel = await makeViewModel()
        let pablo = try person("Pablo Castro", in: viewModel)

        viewModel.beginRename(pablo)
        #expect(viewModel.isRenaming)
        viewModel.renameDraft = "Daniel Ruiz"
        await viewModel.confirmRename(of: pablo)
        #expect(viewModel.errorMessage == "Ya existe una persona con ese nombre.")
        #expect(store.people.contains { $0.name == "Pablo Castro" })

        viewModel.beginRename(pablo)
        viewModel.renameDraft = "Abel Castro"
        await viewModel.confirmRename(of: pablo)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.people.first?.name == "Abel Castro")
        #expect(store.people.first { $0.id == pablo.id }?.name == "Abel Castro")
    }

    @Test func deletingKeepsSavedTimesAndClearsTemplates() async throws {
        let viewModel = await makeViewModel()
        let daniel = try person("Daniel Ruiz", in: viewModel)

        viewModel.requestDelete(daniel)
        #expect(viewModel.isConfirmingDeletion)
        await viewModel.confirmDelete(of: daniel)

        #expect(viewModel.people.contains { $0.id == daniel.id } == false)
        #expect(store.people.contains { $0.id == daniel.id } == false)
        #expect(store.serviceTypes.flatMap(\.blocks).contains { $0.defaultPersonID == daniel.id } == false)
        #expect(store.records.flatMap(\.blocks).contains { $0.personID == daniel.id && $0.personName == "Daniel Ruiz" })
    }
}
