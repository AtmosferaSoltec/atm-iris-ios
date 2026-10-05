//
//  PeopleViewModel.swift
//  iris
//

import Foundation
import Observation

/// People who lead the blocks of a service: add, rename and delete.
@Observable
final class PeopleViewModel {
    // MARK: State

    private(set) var isLoading = true
    /// Alphabetical, Spanish collation.
    private(set) var people: [Person] = []
    /// Times each person led a block in the saved records (skipped blocks don't count).
    private(set) var blockCounts: [Person.ID: Int] = [:]

    var newName = "" { didSet { newNameError = nil } }
    private(set) var newNameError: String?
    private(set) var isAdding = false
    /// Problems with renaming or deleting, shown as a banner.
    private(set) var errorMessage: String?

    /// Person being renamed, and the name being typed.
    private(set) var renameTarget: Person?
    var renameDraft = ""
    /// Person waiting for delete confirmation.
    private(set) var pendingDeletion: Person?

    private let peopleRepository: any PeopleRepository
    private let timeRecords: any TimeRecordRepository

    init(people: any PeopleRepository, timeRecords: any TimeRecordRepository) {
        peopleRepository = people
        self.timeRecords = timeRecords
    }

    // MARK: Derived

    /// "1 bloque", "12 bloques".
    func blockCountText(for person: Person) -> String {
        let count = blockCounts[person.id, default: 0]
        return count == 1 ? String(localized: "1 bloque") : String(localized: "\(count) bloques")
    }

    var isRenaming: Bool {
        get { renameTarget != nil }
        set { if !newValue { renameTarget = nil } }
    }

    var isConfirmingDeletion: Bool {
        get { pendingDeletion != nil }
        set { if !newValue { pendingDeletion = nil } }
    }

    // MARK: Loading

    func load() async {
        guard isLoading else { return }
        let people = (try? await peopleRepository.people()) ?? []
        let records = (try? await timeRecords.records()) ?? []
        apply(people: people, records: records)
    }

    /// Installs loaded data. Also used by previews to start loaded.
    func apply(people: [Person], records: [ServiceRecord]) {
        self.people = Self.sorted(people)
        var counts: [Person.ID: Int] = [:]
        for block in records.flatMap(\.blocks) where block.status != .skipped {
            guard let id = block.personID else { continue }
            counts[id, default: 0] += 1
        }
        blockCounts = counts
        isLoading = false
    }

    // MARK: Adding

    func add() async {
        guard !isAdding else { return }
        if let error = validate(newName, excluding: nil) {
            newNameError = error
            return
        }
        isAdding = true
        defer { isAdding = false }
        do {
            let person = try await peopleRepository.add(name: newName.trimmingCharacters(in: .whitespacesAndNewlines))
            people = Self.sorted(people + [person])
            newName = ""
            errorMessage = nil
        } catch {
            newNameError = String(localized: "Algo salió mal. Inténtalo de nuevo.")
        }
    }

    // MARK: Renaming

    func beginRename(_ person: Person) {
        renameDraft = person.name
        errorMessage = nil
        renameTarget = person
    }

    func confirmRename(of person: Person) async {
        renameTarget = nil
        let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name != person.name else { return }
        if let error = validate(name, excluding: person.id) {
            errorMessage = error
            return
        }
        do {
            try await peopleRepository.rename(person.id, to: name)
            people = Self.sorted(people.map { $0.id == person.id ? Person(id: $0.id, name: name) : $0 })
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
        }
    }

    // MARK: Deleting

    func requestDelete(_ person: Person) {
        errorMessage = nil
        pendingDeletion = person
    }

    /// Saved times keep the person's name; templates forget them as suggested leader.
    func confirmDelete(of person: Person) async {
        pendingDeletion = nil
        do {
            try await peopleRepository.delete(person.id)
            people.removeAll { $0.id == person.id }
        } catch {
            errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
        }
    }

    // MARK: Private

    /// Empty or already taken (ignoring case, accents and spaces).
    private func validate(_ name: String, excluding id: Person.ID?) -> String? {
        let key = name.nameKey
        if key.isEmpty { return String(localized: "Escribe un nombre.") }
        if people.contains(where: { $0.id != id && $0.name.nameKey == key }) {
            return String(localized: "Ya existe una persona con ese nombre.")
        }
        return nil
    }

    private static func sorted(_ people: [Person]) -> [Person] {
        let spanish = Locale(identifier: "es")
        return people.sorted { $0.name.compare($1.name, options: .caseInsensitive, locale: spanish) == .orderedAscending }
    }
}
