//
//  ChurchRepositories.swift
//  iris
//

import Foundation

/// Church-wide module switches.
protocol ModuleSettingsRepository {
    /// Yields when the local copy of this data changes (a sync, another screen).
    func changes() -> AsyncStream<Void>
    func modules() async throws -> ChurchModules
    func save(_ modules: ChurchModules) async throws
}

/// Service types and their optional timed blocks.
protocol ServiceTypeRepository {
    func changes() -> AsyncStream<Void>
    func serviceTypes() async throws -> [ServiceType]
    /// Inserts the type, or replaces the one with the same id.
    func save(_ type: ServiceType) async throws
    func delete(_ id: ServiceType.ID) async throws
}

/// People who can lead a block.
protocol PeopleRepository {
    func changes() -> AsyncStream<Void>
    func people() async throws -> [Person]
    func add(name: String) async throws -> Person
    func rename(_ id: Person.ID, to name: String) async throws
    /// Saved records keep the person's id and name; templates drop them as suggested leader.
    func delete(_ id: Person.ID) async throws
}

/// Saved service timings, newest first.
protocol TimeRecordRepository {
    func changes() -> AsyncStream<Void>
    func records() async throws -> [ServiceRecord]
    /// Inserts the record, or replaces the one with the same id.
    func save(_ record: ServiceRecord) async throws
    /// Corrects the measured duration of a block; it becomes "adjusted".
    func adjust(_ recordID: ServiceRecord.ID, block blockID: BlockRecord.ID, actualSeconds: TimeInterval) async throws
    /// Changes who led a block; the saved name follows the person (or is cleared).
    func changeLeader(_ recordID: ServiceRecord.ID, block blockID: BlockRecord.ID, to personID: Person.ID?) async throws
    func delete(_ id: ServiceRecord.ID) async throws
    /// Whether the record is still waiting to reach the API (saved offline).
    func isPendingUpload(_ id: ServiceRecord.ID) async -> Bool
}

// In-memory data only changes through the screen that edits it: nothing to announce.
extension ModuleSettingsRepository {
    func changes() -> AsyncStream<Void> { .finished }
}

extension ServiceTypeRepository {
    func changes() -> AsyncStream<Void> { .finished }
}

extension PeopleRepository {
    func changes() -> AsyncStream<Void> { .finished }
}

extension TimeRecordRepository {
    func changes() -> AsyncStream<Void> { .finished }
    func isPendingUpload(_ id: ServiceRecord.ID) async -> Bool { false }
}

nonisolated extension AsyncStream where Element == Void {
    /// A stream that ends right away.
    static var finished: AsyncStream<Void> { AsyncStream { $0.finish() } }

    /// Merges several change streams into one.
    static func merged(_ streams: [AsyncStream<Void>]) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for stream in streams {
                        group.addTask {
                            for await _ in stream { continuation.yield() }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
