//
//  StoredModels.swift
//  iris
//
//  SwiftData rows of the local copy. Only `LocalStore` touches them; everything else gets DTOs or app models.
//

import Foundation
import SwiftData

/// Kinds of synchronized content.
nonisolated enum EntityKind: String, Codable, CaseIterable, Sendable {
    case church, people, serviceTypes, songs, media, serviceRecords, servicePlan
}

/// One synchronized row: the contract's JSON of the entity, as last seen or written locally.
@Model
nonisolated final class StoredEntity {
    /// "people/0199…": unique across kinds.
    @Attribute(.unique) var key: String
    var kindRaw: String
    var entityID: String
    var churchID: String
    /// Name key or title key, for ordering without decoding.
    var sortKey: String
    var payload: Data

    init(kind: EntityKind, entityID: String, churchID: String, sortKey: String, payload: Data) {
        key = Self.key(kind, entityID)
        kindRaw = kind.rawValue
        self.entityID = entityID
        self.churchID = churchID
        self.sortKey = sortKey
        self.payload = payload
    }

    static func key(_ kind: EntityKind, _ id: String) -> String { "\(kind.rawValue)/\(id.lowercased())" }
}

/// Which church the local copy belongs to and how far it is synchronized.
@Model
nonisolated final class SyncState {
    @Attribute(.unique) var churchID: String
    var cursor: String
    var lastSyncAt: Date?
    /// Last time the Bible was checked for a new version.
    var bibleCheckedAt: Date?

    init(churchID: String, cursor: String = "0") {
        self.churchID = churchID
        self.cursor = cursor
    }
}

/// A write waiting to reach the API, sent in `sequence` order.
@Model
nonisolated final class OutboxOperation {
    @Attribute(.unique) var id: UUID
    var churchID: String
    var sequence: Int
    var method: String
    var path: String
    var body: Data?
    /// What the write was about, to resynchronize it if the API rejects it.
    var kindRaw: String
    /// Human name of the change ("Ana Torres"), for the rejection message.
    var label: String
    var createdAt: Date
    var attempts: Int
    var lastError: String?

    init(churchID: String, sequence: Int, method: String, path: String, body: Data?, kind: EntityKind, label: String, createdAt: Date) {
        id = UUID()
        self.churchID = churchID
        self.sequence = sequence
        self.method = method
        self.path = path
        self.body = body
        kindRaw = kind.rawValue
        self.label = label
        self.createdAt = createdAt
        attempts = 0
    }
}
