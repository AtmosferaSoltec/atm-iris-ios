//
//  LiveChurchData.swift
//  iris
//

import Foundation

/// What every live repository shares: the local copy, the outbox and the change fan-out.
/// Reads come from the copy; writes go to the copy first, then to the outbox.
struct LiveChurchData {
    let store: LocalStore
    let outbox: Outbox
    let sync: any SyncService
    let changes: ChurchDataChanges
    var now: () -> Date = { .now }

    func changes(of kinds: Set<EntityKind>) -> AsyncStream<Void> {
        changes.stream(for: kinds)
    }

    /// Queues a write already applied locally, tells open screens and sends it soon.
    func write(_ request: APIRequest, kind: EntityKind, label: String, touching kinds: Set<EntityKind>) async throws {
        try await outbox.enqueue(request, kind: kind, label: label)
        changes.publish(kinds)
        sync.flushSoon()
    }
}

/// A local write the copy cannot accept.
nonisolated struct LocalWriteError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}
