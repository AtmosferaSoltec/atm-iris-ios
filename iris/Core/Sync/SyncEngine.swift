//
//  SyncEngine.swift
//  iris
//

import Foundation
import Observation
import os

/// Keeps the local copy in step with the API (contract §12): first the outbox, then
/// `GET /sync/changes` pages from the saved cursor until `hasMore` is false.
@Observable
final class SyncEngine: SyncService {
    private(set) var status: SyncStatus = .idle(lastSync: nil)
    private(set) var initialSync: InitialSyncState = .ready
    private(set) var pendingCount = 0
    private(set) var notice: String?
    var storageWarning: String?

    /// Asked to reload the session after a 403 (a role changed from the web).
    var onForbidden: () async -> Void = {}
    /// Work that follows each successful sync (media downloads, Bible updates).
    var afterSync: [() async -> Void] = []
    /// Work that erases data tied to the copy (cached media files) on sign-out.
    var onDiscard: [() async -> Void] = []

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let client: APIClient
    @ObservationIgnored private let outbox: Outbox
    @ObservationIgnored private let changes: ChurchDataChanges
    @ObservationIgnored private let connectivity: ConnectivityMonitor
    @ObservationIgnored private let now: () -> Date

    @ObservationIgnored private var churchID: String?
    @ObservationIgnored private var isSuspended = false
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var runsAgain = false
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var retryStep = 0
    @ObservationIgnored private var flushSoonTask: Task<Void, Never>?
    @ObservationIgnored private var connectivityTask: Task<Void, Never>?

    /// Waits after a blocked outbox: 5 s, 15 s, 60 s, then every 5 min.
    static let retryDelays: [Duration] = [.seconds(5), .seconds(15), .seconds(60), .seconds(300)]
    static let pageLimit = 200

    private static let logger = Logger(subsystem: "com.atmosfera.iris", category: "sync")

    init(
        store: LocalStore,
        client: APIClient,
        outbox: Outbox,
        changes: ChurchDataChanges,
        connectivity: ConnectivityMonitor = ConnectivityMonitor(),
        now: @escaping () -> Date = { .now }
    ) {
        self.store = store
        self.client = client
        self.outbox = outbox
        self.changes = changes
        self.connectivity = connectivity
        self.now = now
    }

    // MARK: SyncService

    func start(session: UserSession) async {
        let churchID = session.church.id.apiString
        self.churchID = churchID
        do {
            try await store.prepare(for: churchID)
        } catch {
            Self.logger.error("No se pudo preparar la copia local: \(String(describing: error), privacy: .public)")
        }
        pendingCount = await store.pendingCount()
        let lastSync = await store.lastSyncAt()
        status = .idle(lastSync: lastSync)
        initialSync = lastSync == nil ? .loading(pages: 0) : .ready
        watchConnectivity()
        await syncNow(reason: .launch)
    }

    func syncNow(reason: SyncReason) async {
        guard churchID != nil, !isSuspended else { return }
        if let running {
            // One run at a time; a request during a run chains exactly one more.
            runsAgain = true
            await running.value
            return
        }
        let task = Task {
            await self.performSync(reason: reason)
            while self.runsAgain, !self.isSuspended {
                self.runsAgain = false
                await self.performSync(reason: reason)
            }
        }
        running = task
        await task.value
        running = nil
    }

    func flushSoon() {
        Task { pendingCount = await store.pendingCount() }
        // Writes go out even during a service (the record of a finished one, for example);
        // only pulling changes waits until the console closes.
        flushSoonTask?.cancel()
        flushSoonTask = Task {
            // Coalesce a burst of edits into one pass.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await sendOutbox()
        }
    }

    func suspend() {
        isSuspended = true
        retryTask?.cancel()
    }

    func resume() {
        guard isSuspended else { return }
        isSuspended = false
        if pendingCount > 0 { flushSoon() }
    }

    func dismissNotice() {
        notice = nil
    }

    func discardLocalData() async {
        retryTask?.cancel()
        connectivityTask?.cancel()
        connectivityTask = nil
        await running?.value
        churchID = nil
        try? await store.clear()
        for work in onDiscard { await work() }
        pendingCount = 0
        notice = nil
        status = .idle(lastSync: nil)
        initialSync = .ready
    }

    // MARK: Private

    private func performSync(reason: SyncReason) async {
        if case .ready = initialSync {} else { initialSync = .loading(pages: 0) }
        status = .syncing

        guard await sendOutbox() else { return }

        var pages = 0
        do {
            var hasMore = true
            while hasMore, !isSuspended {
                let page = try await client.send(
                    APIRequest(.get, "/sync/changes", query: [
                        URLQueryItem(name: "since", value: await store.cursor()),
                        URLQueryItem(name: "limit", value: String(Self.pageLimit))
                    ]),
                    as: SyncPageDTO.self
                )
                let changed = try await store.apply(page, at: now())
                changes.publish(changed)
                pages += 1
                if case .loading = initialSync { initialSync = .loading(pages: pages) }
                hasMore = page.hasMore
            }
            let lastSync = await store.lastSyncAt()
            status = .idle(lastSync: lastSync)
            initialSync = lastSync == nil ? initialSync : .ready
            for work in afterSync { await work() }
        } catch {
            await handleSyncFailure(error)
        }
    }

    /// Sends the outbox. Returns `true` when it is empty, so the pull can follow without
    /// overwriting local edits that have not reached the API yet.
    @discardableResult
    private func sendOutbox() async -> Bool {
        let (result, rejections) = await outbox.flush()
        pendingCount = await store.pendingCount()
        for rejection in rejections {
            notice = String(localized: "No se pudo guardar «\(rejection.label)»: \(rejection.message)")
            if rejection.isForbidden { await onForbidden() }
            await resynchronize(rejection.kind)
        }
        switch result {
        case .drained:
            retryStep = 0
            retryTask?.cancel()
            return true
        case .blocked:
            status = .offline(pending: pendingCount)
            if case .loading = initialSync, await store.lastSyncAt() == nil { initialSync = .needsConnection }
            scheduleRetry()
            return false
        }
    }

    private func handleSyncFailure(_ error: any Error) async {
        let hasCopy = await store.lastSyncAt() != nil
        let apiError = error as? APIError
        if apiError.map({ $0.isTransient }) ?? false {
            status = .offline(pending: pendingCount)
            if !hasCopy { initialSync = .needsConnection }
            scheduleRetry()
        } else {
            let message = apiError?.message ?? String(localized: "Algo salió mal. Inténtalo de nuevo.")
            Self.logger.error("La sincronización falló: \(String(describing: error), privacy: .public)")
            status = .failed(message: message)
            if !hasCopy { initialSync = .failed(message: message) }
        }
    }

    private func scheduleRetry() {
        guard !isSuspended else { return }
        let delay = Self.retryDelays[min(retryStep, Self.retryDelays.count - 1)]
        retryStep += 1
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await syncNow(reason: .reconnected)
        }
    }

    /// After a rejected write, reloads that kind from its list endpoint to get back to the server's truth.
    private func resynchronize(_ kind: EntityKind) async {
        do {
            switch kind {
            case .church:
                let church = try await client.send(APIRequest(.get, "/church"), as: ChurchDTO.self)
                try await store.upsert(.church, [(church.id, church.name.nameKey, church)])
            case .people:
                let people = try await client.send(APIRequest(.get, "/people"), as: [PersonDTO].self)
                try await store.replaceAll(.people, with: people.map { ($0.id, $0.name.nameKey, $0) })
            case .serviceTypes:
                let types = try await client.send(APIRequest(.get, "/service-types"), as: [ServiceTypeDTO].self)
                try await store.replaceAll(.serviceTypes, with: types.map { ($0.id, $0.name.nameKey, $0) })
            case .serviceRecords:
                var records: [ServiceRecordDTO] = []
                var page = 1
                while true {
                    let result = try await client.sendPage(
                        APIRequest(.get, "/service-records", query: [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "limit", value: "500")]),
                        of: ServiceRecordDTO.self
                    )
                    records += result.data
                    guard page < result.meta.totalPages else { break }
                    page += 1
                }
                try await store.replaceAll(.serviceRecords, with: records.map { ($0.id, LocalStore.newestFirst($0.date), $0) })
            case .songs, .media:
                return
            }
            changes.publish([kind])
        } catch {
            Self.logger.notice("No se pudo volver a cargar \(kind.rawValue, privacy: .public); la próxima sincronización lo corrige.")
        }
    }

    private func watchConnectivity() {
        guard connectivityTask == nil else { return }
        connectivityTask = Task {
            var wasConnected = true
            for await isConnected in connectivity.updates() {
                if isConnected, !wasConnected {
                    retryStep = 0
                    await syncNow(reason: .reconnected)
                } else if !isConnected {
                    status = .offline(pending: pendingCount)
                }
                wasConnected = isConnected
            }
        }
    }
}
