//
//  Outbox.swift
//  iris
//

import Foundation
import os

/// Writes waiting for the API (contract §12). Each one is applied to the local copy first,
/// then queued here and sent in order, one at a time. All of them use idempotent endpoints,
/// so a retry never duplicates anything.
final class Outbox {
    nonisolated enum FlushResult: Equatable, Sendable {
        /// The queue is empty.
        case drained
        /// No network, a server error or no session: the rest waits for the next attempt.
        case blocked
    }

    /// A write the API refused for good (validation, permission, duplicate).
    nonisolated struct Rejection: Equatable, Sendable {
        let kind: EntityKind
        let label: String
        let message: String
        let isForbidden: Bool
    }

    private let store: LocalStore
    private let client: APIClient
    private let now: () -> Date
    private var flushTask: Task<(FlushResult, [Rejection]), Never>?

    private static let logger = Logger(subsystem: "com.atmosfera.iris", category: "sync")

    init(store: LocalStore, client: APIClient, now: @escaping () -> Date = { .now }) {
        self.store = store
        self.client = client
        self.now = now
    }

    func enqueue(_ request: APIRequest, kind: EntityKind, label: String) async throws {
        try await store.enqueue(request, kind: kind, label: label, at: now())
    }

    func pendingCount() async -> Int {
        await store.pendingCount()
    }

    /// Sends every queued write in order. Concurrent calls share the same pass.
    func flush() async -> (FlushResult, [Rejection]) {
        if let flushTask { return await flushTask.value }
        let task = Task { await self.sendAll() }
        flushTask = task
        let result = await task.value
        flushTask = nil
        return result
    }

    private func sendAll() async -> (FlushResult, [Rejection]) {
        var rejections: [Rejection] = []
        for operation in await store.pendingOperations() {
            do {
                try await client.sendVoid(operation.request)
                try? await store.removeOperation(operation.id)
            } catch let error as APIError {
                switch error {
                case .unauthorized, .notConfigured:
                    // The session is gone: the queue stays for the next sign-in to this church.
                    return (.blocked, rejections)
                case _ where error.isTransient:
                    try? await store.markAttempt(operation.id, error: error.message)
                    return (.blocked, rejections)
                default:
                    Self.logger.notice("El API rechazó \(operation.method.rawValue, privacy: .public) \(operation.path, privacy: .public): \(error.code ?? "?", privacy: .public)")
                    try? await store.removeOperation(operation.id)
                    rejections.append(Rejection(kind: operation.kind, label: operation.label, message: error.message, isForbidden: error.status == 403))
                }
            } catch {
                try? await store.markAttempt(operation.id, error: error.localizedDescription)
                return (.blocked, rejections)
            }
        }
        return (.drained, rejections)
    }
}
