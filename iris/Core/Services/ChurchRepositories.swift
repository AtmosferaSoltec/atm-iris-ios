//
//  ChurchRepositories.swift
//  iris
//

import Foundation

/// Church-wide module switches.
protocol ModuleSettingsRepository {
    func modules() async throws -> ChurchModules
    func save(_ modules: ChurchModules) async throws
}

/// Service types and their optional timed blocks.
protocol ServiceTypeRepository {
    func serviceTypes() async throws -> [ServiceType]
    /// Inserts the type, or replaces the one with the same id.
    func save(_ type: ServiceType) async throws
    func delete(_ id: ServiceType.ID) async throws
}

/// People who can lead a block.
protocol PeopleRepository {
    func people() async throws -> [Person]
    func add(name: String) async throws -> Person
    func rename(_ id: Person.ID, to name: String) async throws
    /// Saved records keep the person's id and name; templates drop them as suggested leader.
    func delete(_ id: Person.ID) async throws
}

/// Saved service timings, newest first.
protocol TimeRecordRepository {
    func records() async throws -> [ServiceRecord]
    /// Inserts the record, or replaces the one with the same id.
    func save(_ record: ServiceRecord) async throws
    func delete(_ id: ServiceRecord.ID) async throws
}
