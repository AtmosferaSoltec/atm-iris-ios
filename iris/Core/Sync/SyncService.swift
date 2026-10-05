//
//  SyncService.swift
//  iris
//

import Foundation

/// What the sync indicator shows.
nonisolated enum SyncStatus: Equatable, Sendable {
    case idle(lastSync: Date?)
    case syncing
    /// No connection; `pending` writes wait in the outbox.
    case offline(pending: Int)
    case failed(message: String)
}

/// Download of the first copy of the church after signing in.
nonisolated enum InitialSyncState: Equatable, Sendable {
    /// There is a local copy (or mock data): Home shows it.
    case ready
    /// Downloading: pages applied so far.
    case loading(pages: Int)
    /// No copy and no network.
    case needsConnection
    case failed(message: String)
}

/// Why a sync was asked for (contract §12).
nonisolated enum SyncReason: String, Sendable {
    case launch, returnedHome, periodic, reconnected, manual, rejectedWrite
}

/// Keeps the local copy up to date and sends queued writes. The console pauses it during a service.
protocol SyncService: AnyObject {
    var status: SyncStatus { get }
    var initialSync: InitialSyncState { get }
    var pendingCount: Int { get }
    /// Why a queued write was rejected ("No se pudo guardar «Ana»: …"), until dismissed.
    var notice: String? { get }
    /// Low disk space and other warnings shown with the indicator.
    var storageWarning: String? { get }

    /// Prepares the copy for the session's church and runs the first sync.
    func start(session: UserSession) async
    func syncNow(reason: SyncReason) async
    /// Sends the outbox soon, after a local write.
    func flushSoon()
    /// A service started in the console: no syncing until it ends.
    func suspend()
    func resume()
    func dismissNotice()
    /// Erases the copy and the outbox (sign-out, church switch).
    func discardLocalData() async
}

/// Sync that does nothing: previews, tests and mock mode, whose data never leaves memory.
@Observable
final class MockSyncService: SyncService {
    var status: SyncStatus
    var initialSync: InitialSyncState
    var pendingCount: Int
    var notice: String?
    var storageWarning: String?

    init(status: SyncStatus = .idle(lastSync: .now), initialSync: InitialSyncState = .ready, pendingCount: Int = 0) {
        self.status = status
        self.initialSync = initialSync
        self.pendingCount = pendingCount
    }

    func start(session: UserSession) async {}
    func syncNow(reason: SyncReason) async {}
    func flushSoon() {}
    func suspend() {}
    func resume() {}
    func dismissNotice() { notice = nil }
    func discardLocalData() async {}
}
