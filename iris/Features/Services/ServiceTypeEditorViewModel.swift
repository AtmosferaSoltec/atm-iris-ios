//
//  ServiceTypeEditorViewModel.swift
//  iris
//

import Foundation
import Observation

/// Creates or edits one service type. Works on a draft; only `save()` persists.
@Observable
final class ServiceTypeEditorViewModel: Identifiable {
    /// What the editor did before closing.
    enum Outcome: Equatable {
        case saved(ServiceType)
        case deleted(ServiceType.ID)
    }

    // MARK: Draft

    var name = ""
    var color: UInt32
    var hasSchedule = false
    var weekday = 1
    private(set) var hour = 10
    private(set) var minute = 0
    private(set) var tracksTime = false
    private(set) var blocks: [BlockTemplate] = []

    // MARK: Screen state

    private(set) var people: [Person] = []
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    var isConfirmingBlockRemoval = false
    var isConfirmingDeletion = false

    /// "Agregar persona…" alert, the block it was opened from and the name typed.
    var isAddingPerson = false
    private(set) var personTargetBlockID: BlockTemplate.ID?
    var newPersonName = ""

    let isNew: Bool
    /// Time control is a church module; when it is off the blocks are hidden, never dropped.
    let showsTimeControl: Bool

    private let original: ServiceType?
    private let otherNames: Set<String>
    private let serviceTypeRepository: any ServiceTypeRepository
    private let peopleRepository: any PeopleRepository
    private let onFinish: (Outcome) -> Void

    init(
        editing original: ServiceType?,
        otherTypes: [ServiceType],
        showsTimeControl: Bool,
        serviceTypes: any ServiceTypeRepository,
        people: any PeopleRepository,
        onFinish: @escaping (Outcome) -> Void
    ) {
        self.original = original
        isNew = original == nil
        self.showsTimeControl = showsTimeControl
        otherNames = Set(otherTypes.filter { $0.id != original?.id }.map(\.name.nameKey))
        serviceTypeRepository = serviceTypes
        peopleRepository = people
        self.onFinish = onFinish

        color = original?.color ?? ServiceType.palette[0]
        if let original {
            name = original.name
            if let schedule = original.schedule {
                hasSchedule = true
                weekday = schedule.weekday
                hour = schedule.hour
                minute = schedule.minute
            }
            tracksTime = original.tracksTime
            blocks = original.blocks
        }
    }

    // MARK: Validation

    var nameError: String? {
        otherNames.contains(name.nameKey) ? String(localized: "Ya existe un servicio con ese nombre.") : nil
    }

    func isBlockNameMissing(_ id: BlockTemplate.ID) -> Bool {
        blocks.first { $0.id == id }?.name.nameKey.isEmpty ?? false
    }

    var blocksError: String? {
        guard showsTimeControl, tracksTime, blocks.isEmpty else { return nil }
        return String(localized: "Agrega al menos un bloque o desactiva el control de tiempo.")
    }

    var canSave: Bool {
        guard !name.nameKey.isEmpty, nameError == nil, blocksError == nil else { return false }
        guard showsTimeControl, tracksTime else { return true }
        return !blocks.contains { $0.name.nameKey.isEmpty }
    }

    // MARK: Derived

    var plannedSeconds: TimeInterval { blocks.reduce(0) { $0 + $1.plannedSeconds } }

    /// Bound to the time picker; only hour and minute matter.
    var scheduleTime: Date {
        get { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            hour = components.hour ?? hour
            minute = components.minute ?? minute
        }
    }

    func personName(_ id: Person.ID?) -> String? {
        people.first { $0.id == id }?.name
    }

    // MARK: Loading

    func load() async {
        apply(people: (try? await peopleRepository.people()) ?? people)
    }

    /// Installs the people offered as block leaders. Also used by previews.
    func apply(people: [Person]) {
        let spanish = Locale(identifier: "es")
        self.people = people.sorted { $0.name.compare($1.name, options: .caseInsensitive, locale: spanish) == .orderedAscending }
    }

    // MARK: Time control

    /// Turning it on starts with one block; turning it off with blocks asks first.
    func setTracksTime(_ isOn: Bool) {
        if isOn {
            tracksTime = true
            if blocks.isEmpty { addBlock() }
        } else if blocks.isEmpty {
            tracksTime = false
        } else {
            isConfirmingBlockRemoval = true
        }
    }

    func confirmBlockRemoval() {
        blocks = []
        tracksTime = false
    }

    func addBlock() {
        blocks.append(BlockTemplate(name: String(localized: "Nuevo bloque"), plannedMinutes: 10))
    }

    func removeBlock(_ id: BlockTemplate.ID) {
        blocks.removeAll { $0.id == id }
    }

    func blockName(_ id: BlockTemplate.ID) -> String {
        blocks.first { $0.id == id }?.name ?? ""
    }

    func renameBlock(_ id: BlockTemplate.ID, to name: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].name = name
    }

    static let minuteRange = 1...240

    func setMinutes(_ minutes: Int, of id: BlockTemplate.ID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].plannedMinutes = min(max(minutes, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
    }

    func setPerson(_ personID: Person.ID?, for blockID: BlockTemplate.ID) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        blocks[index].defaultPersonID = personID
    }

    /// Applies a drag-to-reorder result: moves `ids` before `target` (or to the end).
    func moveBlocks(_ ids: [BlockTemplate.ID], before target: BlockTemplate.ID?) {
        let moving = ids.compactMap { id in blocks.first { $0.id == id } }
        var list = blocks
        list.removeAll { ids.contains($0.id) }
        let insertIndex = target.flatMap { id in list.firstIndex { $0.id == id } } ?? list.count
        list.insert(contentsOf: moving, at: insertIndex)
        blocks = list
    }

    // MARK: Adding a leader

    func beginAddPerson(for blockID: BlockTemplate.ID) {
        newPersonName = ""
        personTargetBlockID = blockID
        isAddingPerson = true
    }

    /// Creates the person (or reuses one with the same name) and makes them the block's leader.
    func confirmAddPerson() async {
        guard let blockID = personTargetBlockID else { return }
        personTargetBlockID = nil
        let key = newPersonName.nameKey
        guard !key.isEmpty else { return }

        if let existing = people.first(where: { $0.name.nameKey == key }) {
            setPerson(existing.id, for: blockID)
            return
        }
        do {
            let person = try await peopleRepository.add(name: newPersonName.trimmingCharacters(in: .whitespacesAndNewlines))
            apply(people: people + [person])
            setPerson(person.id, for: blockID)
        } catch {
            errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
        }
    }

    // MARK: Saving

    func save() async {
        guard canSave, !isSaving else { return }
        isSaving = true
        errorMessage = nil

        var type = original ?? ServiceType(name: "", color: color, schedule: nil)
        type.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        type.color = color
        type.schedule = hasSchedule ? ServiceType.Schedule(weekday: weekday, hour: hour, minute: minute) : nil
        if showsTimeControl {
            type.blocks = tracksTime
                ? blocks.map { block in
                    var block = block
                    block.name = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return block
                }
                : []
        }

        do {
            try await serviceTypeRepository.save(type)
            onFinish(.saved(type))
        } catch {
            errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
        }
        isSaving = false
    }

    // MARK: Deleting

    func requestDelete() {
        isConfirmingDeletion = true
    }

    /// Saved times of this service are kept.
    func delete() async {
        guard let original, !isSaving else { return }
        isSaving = true
        do {
            try await serviceTypeRepository.delete(original.id)
            onFinish(.deleted(original.id))
        } catch {
            errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
        }
        isSaving = false
    }
}
