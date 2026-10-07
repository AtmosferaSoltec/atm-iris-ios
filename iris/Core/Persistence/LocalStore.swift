//
//  LocalStore.swift
//  iris
//

import Foundation
import SwiftData

/// A queued write as the rest of the app sees it.
nonisolated struct PendingOperation: Identifiable, Hashable, Sendable {
    let id: UUID
    let sequence: Int
    let method: APIRequest.Method
    let path: String
    let body: Data?
    let kind: EntityKind
    let label: String
    let attempts: Int

    var request: APIRequest { APIRequest(method: method, path: path, body: body) }
}

/// The church's local copy (contract §12): what the console shows when offline, plus the outbox.
/// Reads return DTOs; repositories map them to app models.
@ModelActor
actor LocalStore {
    /// Opens the store in `Application Support/Store/`, outside iCloud backups.
    static func onDisk() throws -> LocalStore {
        let folder = URL.applicationSupportDirectory.appending(path: "Store", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = folder
        try? excluded.setResourceValues(values)
        let configuration = ModelConfiguration(url: folder.appending(path: "iris.store"), cloudKitDatabase: .none)
        return LocalStore(modelContainer: try ModelContainer(for: Self.schema, configurations: configuration))
    }

    /// A store that lives in memory. Used by tests.
    static func inMemory() throws -> LocalStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return LocalStore(modelContainer: try ModelContainer(for: Self.schema, configurations: configuration))
    }

    nonisolated static let schema = Schema([StoredEntity.self, SyncState.self, OutboxOperation.self])

    // MARK: Church scope

    /// The church the copy belongs to, if any.
    func churchID() -> String? {
        (try? modelContext.fetch(FetchDescriptor<SyncState>()))?.first?.churchID
    }

    /// Makes the copy belong to `churchID`. A copy of another church is erased first.
    func prepare(for churchID: String) throws {
        if let current = self.churchID(), current == churchID { return }
        try clear()
        modelContext.insert(SyncState(churchID: churchID))
        try modelContext.save()
    }

    /// Erases the whole copy and the outbox (sign-out, church switch).
    func clear() throws {
        try modelContext.delete(model: StoredEntity.self)
        try modelContext.delete(model: SyncState.self)
        try modelContext.delete(model: OutboxOperation.self)
        try modelContext.save()
    }

    // MARK: Reading

    func all<T: Decodable & Sendable>(_ kind: EntityKind, as type: T.Type) -> [T] {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<StoredEntity>(
            predicate: #Predicate { $0.kindRaw == raw },
            sortBy: [SortDescriptor(\.sortKey)]
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        let decoder = JSONCoding.decoder
        return rows.compactMap { try? decoder.decode(T.self, from: $0.payload) }
    }

    func one<T: Decodable & Sendable>(_ kind: EntityKind, id: String, as type: T.Type) -> T? {
        row(kind, id).flatMap { try? JSONCoding.decoder.decode(T.self, from: $0.payload) }
    }

    func count(_ kind: EntityKind) -> Int {
        let raw = kind.rawValue
        return (try? modelContext.fetchCount(FetchDescriptor<StoredEntity>(predicate: #Predicate { $0.kindRaw == raw }))) ?? 0
    }

    var hasCopy: Bool { syncState()?.lastSyncAt != nil }

    // MARK: Writing (local edits)

    /// Inserts or replaces entities written locally.
    func upsert<T: Encodable & Sendable>(_ kind: EntityKind, _ items: [(id: String, sortKey: String, value: T)]) throws {
        guard let churchID = churchID() else { return }
        let encoder = JSONCoding.encoder
        for item in items {
            try write(kind, id: item.id, sortKey: item.sortKey, payload: encoder.encode(item.value), churchID: churchID)
        }
        try modelContext.save()
    }

    func delete(_ kind: EntityKind, ids: [String]) throws {
        for id in ids {
            if let row = row(kind, id) { modelContext.delete(row) }
        }
        try modelContext.save()
    }

    /// Replaces every entity of a kind with the server's list (used to recover after a rejected write).
    func replaceAll<T: Encodable & Sendable>(_ kind: EntityKind, with items: [(id: String, sortKey: String, value: T)]) throws {
        guard let churchID = churchID() else { return }
        let raw = kind.rawValue
        try modelContext.delete(model: StoredEntity.self, where: #Predicate { $0.kindRaw == raw })
        let encoder = JSONCoding.encoder
        for item in items {
            modelContext.insert(StoredEntity(kind: kind, entityID: item.id, churchID: churchID, sortKey: item.sortKey, payload: try encoder.encode(item.value)))
        }
        try modelContext.save()
    }

    // MARK: Sync

    /// Applies one page of `GET /sync/changes` and its cursor in a single transaction.
    /// Returns the kinds that changed.
    func apply(_ page: SyncPageDTO, at date: Date) throws -> Set<EntityKind> {
        guard let state = syncState() else { return [] }
        let churchID = state.churchID
        let encoder = JSONCoding.encoder
        var changed: Set<EntityKind> = []

        func put<T: Encodable>(_ kind: EntityKind, _ id: String, _ sortKey: String, _ value: T) throws {
            try write(kind, id: id, sortKey: sortKey, payload: encoder.encode(value), churchID: churchID)
            changed.insert(kind)
        }

        if let church = page.church { try put(.church, church.id, church.name.nameKey, church) }
        for person in page.changes.people { try put(.people, person.id, person.name.nameKey, person) }
        for type in page.changes.serviceTypes { try put(.serviceTypes, type.id, type.name.nameKey, type) }
        for song in page.changes.songs { try put(.songs, song.id, song.title.nameKey, song) }
        for asset in page.changes.media { try put(.media, asset.id, Self.newestFirst(asset.createdAt), asset) }
        for record in page.changes.serviceRecords { try put(.serviceRecords, record.id, Self.newestFirst(record.date), record) }
        for entry in page.changes.servicePlan { try put(.servicePlan, entry.id, Self.position(entry.position), entry) }

        let deletions: [(EntityKind, [String])] = [
            (.people, page.deleted.people), (.serviceTypes, page.deleted.serviceTypes), (.songs, page.deleted.songs),
            (.media, page.deleted.media), (.serviceRecords, page.deleted.serviceRecords),
            (.servicePlan, page.deleted.servicePlan)
        ]
        for (kind, ids) in deletions {
            for id in ids {
                if let row = row(kind, id) {
                    modelContext.delete(row)
                    changed.insert(kind)
                }
            }
        }

        state.cursor = page.cursor
        if !page.hasMore { state.lastSyncAt = date }
        try modelContext.save()
        return changed
    }

    func cursor() -> String { syncState()?.cursor ?? "0" }

    func lastSyncAt() -> Date? { syncState()?.lastSyncAt }

    func bibleCheckedAt() -> Date? { syncState()?.bibleCheckedAt }

    func setBibleCheckedAt(_ date: Date) throws {
        syncState()?.bibleCheckedAt = date
        try modelContext.save()
    }

    // MARK: Outbox

    func enqueue(_ request: APIRequest, kind: EntityKind, label: String, at date: Date) throws {
        guard let churchID = churchID() else { return }
        let last = try modelContext.fetch(Self.outboxDescriptor(limit: nil)).last?.sequence ?? 0
        modelContext.insert(OutboxOperation(
            churchID: churchID, sequence: last + 1, method: request.method.rawValue, path: request.path,
            body: request.body, kind: kind, label: label, createdAt: date
        ))
        try modelContext.save()
    }

    func pendingOperations() -> [PendingOperation] {
        let rows = (try? modelContext.fetch(Self.outboxDescriptor(limit: nil))) ?? []
        return rows.compactMap { row in
            guard let method = APIRequest.Method(rawValue: row.method), let kind = EntityKind(rawValue: row.kindRaw) else { return nil }
            return PendingOperation(id: row.id, sequence: row.sequence, method: method, path: row.path, body: row.body, kind: kind, label: row.label, attempts: row.attempts)
        }
    }

    func pendingCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<OutboxOperation>())) ?? 0
    }

    /// Whether a write to `path` is still waiting (e.g. a record saved offline).
    func hasPendingOperation(path: String) -> Bool {
        let descriptor = FetchDescriptor<OutboxOperation>(predicate: #Predicate { $0.path == path })
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    func removeOperation(_ id: UUID) throws {
        try modelContext.delete(model: OutboxOperation.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }

    func markAttempt(_ id: UUID, error: String) throws {
        let descriptor = FetchDescriptor<OutboxOperation>(predicate: #Predicate { $0.id == id })
        guard let row = try modelContext.fetch(descriptor).first else { return }
        row.attempts += 1
        row.lastError = error
        try modelContext.save()
    }

    // MARK: Private

    private func syncState() -> SyncState? {
        (try? modelContext.fetch(FetchDescriptor<SyncState>()))?.first
    }

    private func row(_ kind: EntityKind, _ id: String) -> StoredEntity? {
        let key = StoredEntity.key(kind, id)
        var descriptor = FetchDescriptor<StoredEntity>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func write(_ kind: EntityKind, id: String, sortKey: String, payload: Data, churchID: String) throws {
        if let existing = row(kind, id) {
            existing.payload = payload
            existing.sortKey = sortKey
        } else {
            modelContext.insert(StoredEntity(kind: kind, entityID: id.lowercased(), churchID: churchID, sortKey: sortKey, payload: payload))
        }
    }

    private static func outboxDescriptor(limit: Int?) -> FetchDescriptor<OutboxOperation> {
        var descriptor = FetchDescriptor<OutboxOperation>(sortBy: [SortDescriptor(\.sequence)])
        descriptor.fetchLimit = limit
        return descriptor
    }

    /// Sort key that orders dates newest first.
    static func newestFirst(_ date: Date) -> String {
        String(format: "%015.0f", 9_999_999_999_999 - date.timeIntervalSince1970 * 1000)
    }

    /// Sort key that orders a service plan's items by `position`.
    static func position(_ position: Int) -> String {
        String(format: "%05d", position)
    }
}
