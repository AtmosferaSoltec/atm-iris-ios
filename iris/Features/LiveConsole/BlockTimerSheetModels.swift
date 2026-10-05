//
//  BlockTimerSheetModels.swift
//  iris
//

import Foundation
import Observation

/// "¿Quién dirige {bloque}?": pick the leader before a block starts.
@Observable
final class ResponsiblePickerViewModel: Identifiable {
    let blockName: String
    let suggestedPersonID: Person.ID?
    /// Suggested person first, then alphabetical.
    private(set) var people: [Person]
    var selectedPersonID: Person.ID?
    var newName = ""
    private(set) var isAdding = false

    private let peopleRepository: any PeopleRepository
    private let onPersonAdded: (Person) -> Void
    private let onConfirm: (Person.ID?) -> Void

    init(
        blockName: String,
        suggestedPersonID: Person.ID?,
        people: [Person],
        peopleRepository: any PeopleRepository,
        onPersonAdded: @escaping (Person) -> Void,
        onConfirm: @escaping (Person.ID?) -> Void
    ) {
        self.blockName = blockName
        self.suggestedPersonID = suggestedPersonID
        self.people = Self.ordered(people, suggested: suggestedPersonID)
        selectedPersonID = people.contains { $0.id == suggestedPersonID } ? suggestedPersonID : nil
        self.peopleRepository = peopleRepository
        self.onPersonAdded = onPersonAdded
        self.onConfirm = onConfirm
    }

    func isSuggested(_ person: Person) -> Bool { person.id == suggestedPersonID }

    func select(_ id: Person.ID) {
        selectedPersonID = selectedPersonID == id ? nil : id
    }

    func confirm() {
        onConfirm(selectedPersonID)
    }

    func confirmWithoutLeader() {
        onConfirm(nil)
    }

    /// Creates and selects the person, or selects the one that already has that name.
    func addPerson() async {
        let key = newName.nameKey
        guard !key.isEmpty, !isAdding else { return }
        if let existing = people.first(where: { $0.name.nameKey == key }) {
            selectedPersonID = existing.id
            newName = ""
            return
        }
        isAdding = true
        defer { isAdding = false }
        guard let person = try? await peopleRepository.add(name: newName.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        people.append(person)
        selectedPersonID = person.id
        newName = ""
        onPersonAdded(person)
    }

    private static func ordered(_ people: [Person], suggested: Person.ID?) -> [Person] {
        let spanish = Locale(identifier: "es")
        let sorted = people.sorted { $0.name.compare($1.name, options: .caseInsensitive, locale: spanish) == .orderedAscending }
        guard let suggested, let person = sorted.first(where: { $0.id == suggested }) else { return sorted }
        return [person] + sorted.filter { $0.id != suggested }
    }
}

/// "Agregar bloque": a block for today only, unless the template is updated at the end.
@Observable
final class AddBlockViewModel: Identifiable {
    var name = ""
    var minutes = 10
    var personID: Person.ID?
    let people: [Person]

    private let onAdd: (String, Int, Person.ID?) -> Void

    init(people: [Person], onAdd: @escaping (String, Int, Person.ID?) -> Void) {
        let spanish = Locale(identifier: "es")
        self.people = people.sorted { $0.name.compare($1.name, options: .caseInsensitive, locale: spanish) == .orderedAscending }
        self.onAdd = onAdd
    }

    var canAdd: Bool { !name.nameKey.isEmpty }

    func add() {
        guard canAdd else { return }
        onAdd(name.trimmingCharacters(in: .whitespacesAndNewlines), minutes, personID)
    }
}
