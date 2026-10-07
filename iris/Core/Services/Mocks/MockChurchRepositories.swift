//
//  MockChurchRepositories.swift
//  iris
//

import Foundation

// The four church repositories read and write one shared `InMemoryChurchStore`,
// so changes made on one screen show up on the others during the app run.
// They are separate types because their `delete(_:)` methods all take a UUID.

struct MockModuleSettingsRepository: ModuleSettingsRepository {
    let store: InMemoryChurchStore
    var latency: Duration = .milliseconds(250)

    func modules() async throws -> ChurchModules {
        try await Task.sleep(for: latency)
        return store.modules
    }

    func availableModules() async -> ChurchModules { store.availableModules }

    func save(_ modules: ChurchModules) async throws {
        try await Task.sleep(for: latency)
        store.modules = modules
    }
}

struct MockProjectionSettingsRepository: ProjectionSettingsRepository {
    let store: InMemoryChurchStore
    var latency: Duration = .milliseconds(250)

    func settings() async throws -> ProjectionSettings {
        try await Task.sleep(for: latency)
        return store.projection
    }

    func save(_ settings: ProjectionSettings) async throws {
        try await Task.sleep(for: latency)
        store.projection = settings
    }
}

struct MockServiceTypeRepository: ServiceTypeRepository {
    let store: InMemoryChurchStore
    var latency: Duration = .milliseconds(250)

    func serviceTypes() async throws -> [ServiceType] {
        try await Task.sleep(for: latency)
        return store.serviceTypes
    }

    func save(_ type: ServiceType) async throws {
        try await Task.sleep(for: latency)
        if let index = store.serviceTypes.firstIndex(where: { $0.id == type.id }) {
            store.serviceTypes[index] = type
        } else {
            store.serviceTypes.append(type)
        }
    }

    func delete(_ id: ServiceType.ID) async throws {
        try await Task.sleep(for: latency)
        // Records keep their serviceTypeID: saved times outlive the type.
        store.serviceTypes.removeAll { $0.id == id }
    }
}

struct MockPeopleRepository: PeopleRepository {
    let store: InMemoryChurchStore
    var latency: Duration = .milliseconds(250)

    func people() async throws -> [Person] {
        try await Task.sleep(for: latency)
        return store.people
    }

    func add(name: String) async throws -> Person {
        try await Task.sleep(for: latency)
        let person = Person(name: name)
        store.people.append(person)
        return person
    }

    func rename(_ id: Person.ID, to name: String) async throws {
        try await Task.sleep(for: latency)
        guard let index = store.people.firstIndex(where: { $0.id == id }) else { return }
        store.people[index].name = name
    }

    func delete(_ id: Person.ID) async throws {
        try await Task.sleep(for: latency)
        store.people.removeAll { $0.id == id }
        // Records keep personID and personName; only templates forget the suggested leader.
        for typeIndex in store.serviceTypes.indices {
            for blockIndex in store.serviceTypes[typeIndex].blocks.indices
            where store.serviceTypes[typeIndex].blocks[blockIndex].defaultPersonID == id {
                store.serviceTypes[typeIndex].blocks[blockIndex].defaultPersonID = nil
            }
        }
    }
}

struct MockTimeRecordRepository: TimeRecordRepository {
    let store: InMemoryChurchStore
    var latency: Duration = .milliseconds(250)

    func records() async throws -> [ServiceRecord] {
        try await Task.sleep(for: latency)
        return store.records
    }

    func save(_ record: ServiceRecord) async throws {
        try await Task.sleep(for: latency)
        if let index = store.records.firstIndex(where: { $0.id == record.id }) {
            store.records[index] = record
        } else {
            store.records.append(record)
        }
        store.records.sort { $0.date > $1.date }
    }

    func adjust(_ recordID: ServiceRecord.ID, block blockID: BlockRecord.ID, actualSeconds: TimeInterval) async throws {
        try await Task.sleep(for: latency)
        update(recordID, blockID) { block in
            block.actualSeconds = max(0, actualSeconds)
            block.status = .adjusted
        }
    }

    func changeLeader(_ recordID: ServiceRecord.ID, block blockID: BlockRecord.ID, to personID: Person.ID?) async throws {
        try await Task.sleep(for: latency)
        let name = personID.flatMap { id in store.people.first { $0.id == id }?.name }
        update(recordID, blockID) { block in
            block.personID = personID
            block.personName = name
        }
    }

    func delete(_ id: ServiceRecord.ID) async throws {
        try await Task.sleep(for: latency)
        store.records.removeAll { $0.id == id }
    }

    private func update(_ recordID: ServiceRecord.ID, _ blockID: BlockRecord.ID, change: (inout BlockRecord) -> Void) {
        guard let recordIndex = store.records.firstIndex(where: { $0.id == recordID }),
              let blockIndex = store.records[recordIndex].blocks.firstIndex(where: { $0.id == blockID }) else { return }
        change(&store.records[recordIndex].blocks[blockIndex])
    }
}
