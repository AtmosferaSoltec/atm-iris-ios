//
//  SyncEngineTests.swift
//  irisTests
//

import Foundation
import Synchronization
import Testing
@testable import iris

/// A live stack over an in-memory copy and a fake API.
struct LiveStack {
    let server: StubServer
    let store: LocalStore
    let sync: SyncEngine
    let data: LiveChurchData

    init(_ handler: @escaping StubServer.Handler) throws {
        server = StubServer(handler)
        let client = server.client(tokenProvider: { "token" })
        store = try LocalStore.inMemory()
        let changes = ChurchDataChanges()
        let outbox = Outbox(store: store, client: client)
        sync = SyncEngine(store: store, client: client, outbox: outbox, changes: changes)
        data = LiveChurchData(store: store, outbox: outbox, sync: sync, changes: changes)
    }

    static let session = UserSession.preview

    /// Prepares the copy for the preview church without hitting the network.
    func prepare() async throws {
        try await store.prepare(for: Self.session.church.id.apiString)
    }
}

/// Pages in order, cursor, deletions and the pause during a service (contract §12).
struct SyncEngineTests {
    private let ana = "0199dddd-0000-7000-8000-000000000001"
    private let luis = "0199dddd-0000-7000-8000-000000000002"

    @Test func appliesPagesUntilHasMoreIsFalse() async throws {
        let stack = try LiveStack { request in
            switch request.query["since"] {
            case "0":
                .data(ContractSamples.syncPage(church: ContractSamples.church, people: [ContractSamples.person("0199dddd-0000-7000-8000-000000000001", "Ana Torres")], cursor: "5", hasMore: true))
            case "5":
                .data(ContractSamples.syncPage(people: [ContractSamples.person("0199dddd-0000-7000-8000-000000000002", "Luis Vega")], cursor: "9", hasMore: false))
            default:
                .error(400, code: "VALIDATION_FAILED")
            }
        }
        await stack.sync.start(session: LiveStack.session)

        #expect(stack.server.requests.map { $0.query["since"] } == ["0", "5"])
        #expect(stack.server.requests.allSatisfy { $0.query["limit"] == "200" })
        #expect(await stack.store.cursor() == "9")
        #expect(await stack.store.all(.people, as: PersonDTO.self).map(\.name) == ["Ana Torres", "Luis Vega"])
        #expect(stack.sync.initialSync == .ready)
        let modules = try await LiveModuleSettingsRepository(data: stack.data).modules()
        #expect(modules.multimedia == false)
    }

    @Test func nextSyncStartsFromTheSavedCursorAndAppliesDeletions() async throws {
        let ana = ana
        let stack = try LiveStack { request in
            request.query["since"] == "0"
                ? .data(ContractSamples.syncPage(people: [ContractSamples.person(ana, "Ana Torres")], cursor: "7", hasMore: false))
                : .data(ContractSamples.syncPage(deletedPeople: [ana], cursor: "8", hasMore: false))
        }
        await stack.sync.start(session: LiveStack.session)
        await stack.sync.syncNow(reason: .manual)

        #expect(stack.server.requests.last?.query["since"] == "7")
        #expect(await stack.store.count(.people) == 0)
        #expect(await stack.store.cursor() == "8")
    }

    @Test func noSyncWhileAServiceRuns() async throws {
        let stack = try LiveStack { _ in .data(ContractSamples.syncPage(cursor: "1", hasMore: false)) }
        await stack.sync.start(session: LiveStack.session)
        let before = stack.server.requests.count
        stack.sync.suspend()
        await stack.sync.syncNow(reason: .periodic)
        #expect(stack.server.requests.count == before)
        stack.sync.resume()
        await stack.sync.syncNow(reason: .returnedHome)
        #expect(stack.server.requests.count == before + 1)
    }

    @Test func firstSyncWithoutNetworkAsksForConnection() async throws {
        let stack = try LiveStack { _ in .offline }
        await stack.sync.start(session: LiveStack.session)
        #expect(stack.sync.initialSync == .needsConnection)
        #expect(stack.sync.status == .offline(pending: 0))
    }

    @Test func anotherChurchErasesTheCopy() async throws {
        let stack = try LiveStack { _ in .offline }
        try await stack.prepare()
        try await stack.store.upsert(.people, [("0199dddd-0000-7000-8000-000000000001", "ana", try JSONCoding.decoder.decode(PersonDTO.self, from: Data(ContractSamples.person("0199dddd-0000-7000-8000-000000000001", "Ana").utf8)))])
        #expect(await stack.store.count(.people) == 1)
        try await stack.store.prepare(for: UUID().apiString)
        #expect(await stack.store.count(.people) == 0)
    }
}

/// Order, retries with the network down, rejected writes and idempotent ids.
struct OutboxTests {
    @Test func sendsInOrderAndEmptiesTheQueue() async throws {
        let stack = try LiveStack { request in
            request.method == "GET" ? .data(ContractSamples.syncPage(cursor: "1", hasMore: false)) : .noContent
        }
        try await stack.prepare()
        let people = LivePeopleRepository(data: stack.data)
        let ana = try await people.add(name: "Ana Torres")
        try await people.rename(ana.id, to: "Ana María Torres")
        await stack.sync.start(session: LiveStack.session)

        let writes = stack.server.requests.filter { $0.method != "GET" }
        #expect(writes.map(\.method) == ["POST", "PATCH"])
        #expect(writes.first?.path == "/people")
        #expect(try writes.first?.json([String: String].self)["id"] == ana.id.apiString)
        #expect(await stack.store.pendingCount() == 0)
    }

    @Test func networkDownKeepsTheQueueAndSkipsThePull() async throws {
        let stack = try LiveStack { _ in .offline }
        try await stack.prepare()
        _ = try await LivePeopleRepository(data: stack.data).add(name: "Ana Torres")
        await stack.sync.start(session: LiveStack.session)

        #expect(await stack.store.pendingCount() == 1)
        #expect(stack.sync.status == .offline(pending: 1))
        #expect(!stack.server.requests.contains { $0.path == "/sync/changes" })
        // The local copy already shows the person.
        #expect(try await LivePeopleRepository(data: stack.data).people().map(\.name) == ["Ana Torres"])
    }

    @Test func retryUsesTheSameIdSoNothingDuplicates() async throws {
        let isOnline = Mutex(false)
        let stack = try LiveStack { request in
            guard isOnline.withLock({ $0 }) else { return .offline }
            return request.method == "GET" ? .data(ContractSamples.syncPage(cursor: "1", hasMore: false)) : .noContent
        }
        try await stack.prepare()
        let person = try await LivePeopleRepository(data: stack.data).add(name: "Ana Torres")
        await stack.sync.start(session: LiveStack.session)
        isOnline.withLock { $0 = true }
        await stack.sync.syncNow(reason: .reconnected)

        // The offline attempt and the retry carry the same id, so the API creates the person once.
        let ids = try stack.server.requests.filter { $0.method == "POST" }.map { try $0.json([String: String].self)["id"] }
        #expect(ids.count == 2)
        #expect(Set(ids) == [person.id.apiString])
        #expect(await stack.store.pendingCount() == 0)
    }

    @Test func rejectedWriteIsDroppedAndExplained() async throws {
        let stack = try LiveStack { request in
            switch (request.method, request.path) {
            case ("POST", "/people"): .error(409, code: "PERSON_NAME_TAKEN", message: "Ya existe una persona con ese nombre.")
            case ("GET", "/people"): .data("[]")
            default: .data(ContractSamples.syncPage(cursor: "1", hasMore: false))
            }
        }
        try await stack.prepare()
        _ = try await LivePeopleRepository(data: stack.data).add(name: "Ana Torres")
        await stack.sync.start(session: LiveStack.session)

        #expect(await stack.store.pendingCount() == 0)
        #expect(stack.sync.notice == "No se pudo guardar «Ana Torres»: Ya existe una persona con ese nombre.")
        // Back to the server's truth.
        #expect(await stack.store.count(.people) == 0)
        #expect(stack.server.requests.contains { $0.method == "GET" && $0.path == "/people" })
    }
}

/// People and service types over the local copy.
struct LiveRepositoryTests {
    @Test func duplicateNamesAreRejectedByNameKey() async throws {
        let stack = try LiveStack { _ in .offline }
        try await stack.prepare()
        let people = LivePeopleRepository(data: stack.data)
        _ = try await people.add(name: "José  Pérez")
        await #expect(throws: LocalWriteError.self) {
            _ = try await people.add(name: " jose perez ")
        }
        #expect(try await people.people().count == 1)
    }

    @Test func deletingAPersonClearsTemplates() async throws {
        let stack = try LiveStack { _ in .offline }
        try await stack.prepare()
        let people = LivePeopleRepository(data: stack.data)
        let types = LiveServiceTypeRepository(data: stack.data)
        let ana = try await people.add(name: "Ana Torres")
        let culto = ServiceType(name: "Culto general", color: 0xFFB547, schedule: nil, blocks: [
            BlockTemplate(name: "Alabanzas", plannedMinutes: 15, defaultPersonID: ana.id)
        ])
        try await types.save(culto)

        try await people.delete(ana.id)

        #expect(try await types.serviceTypes().first?.blocks.first?.defaultPersonID == nil)
        let operations = await stack.store.pendingOperations()
        #expect(operations.map(\.method) == [.post, .put, .delete])
        #expect(operations[1].path == "/service-types/\(culto.id.apiString)")
    }

    @Test func savingARecordQueuesAnIdempotentPut() async throws {
        let stack = try LiveStack { _ in .offline }
        try await stack.prepare()
        let records = LiveTimeRecordRepository(data: stack.data)
        let record = ServiceRecord(date: .now, serviceTypeID: UUID(), serviceTypeName: "Culto general", blocks: [
            BlockRecord(name: "Prédica", plannedSeconds: 2400, actualSeconds: 2500, personID: nil)
        ])
        try await records.save(record)
        try await records.save(record)

        #expect(await records.isPendingUpload(record.id))
        let puts = await stack.store.pendingOperations()
        #expect(puts.allSatisfy { $0.method == .put && $0.path == "/service-records/\(record.id.apiString)" })
        #expect(try await records.records().count == 1)

        try await records.adjust(record.id, block: record.blocks[0].id, actualSeconds: 2450)
        let adjusted = try await records.records().first?.blocks.first
        #expect(adjusted?.status == .adjusted)
        #expect(adjusted?.actualSeconds == 2450)
        #expect(await stack.store.pendingOperations().last?.method == .patch)
    }
}
