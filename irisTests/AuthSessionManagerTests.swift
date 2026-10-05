//
//  AuthSessionManagerTests.swift
//  irisTests
//

import Foundation
import Synchronization
import Testing
@testable import iris

/// Token cycle of contract §4.1, against a fake API.
struct AuthSessionManagerTests {
    private let now = JSONCoding.date(from: "2026-10-05T15:30:00.000Z")!

    private func manager(_ server: StubServer, expiresAt: Date) async throws -> (AuthSessionManager, InMemoryTokenStore) {
        let tokens = InMemoryTokenStore()
        let fixedNow = now
        let manager = AuthSessionManager(client: server.client(), tokenStore: tokens, sessionFile: nil, now: { fixedNow })
        let result = try JSONCoding.decoder.decode(
            DataEnvelope<AuthResultDTO>.self,
            from: Data("{\"data\":\(ContractSamples.authResult(accessExpiresAt: JSONCoding.string(from: expiresAt)))}".utf8)
        ).data
        try await manager.establish(result)
        return (manager, tokens)
    }

    private func refreshed(_ token: String) -> StubServer.Response {
        .data(ContractSamples.authResult(accessExpiresAt: "2026-10-05T15:45:00.000Z", token: token, refresh: "refresh-\(token)"))
    }

    @Test func freshTokenIsUsedWithoutRefreshing() async throws {
        let server = StubServer { _ in .error(500, code: "INTERNAL_ERROR") }
        let (manager, _) = try await manager(server, expiresAt: now.addingTimeInterval(600))
        #expect(await manager.currentAccessToken() == "access-1")
        #expect(server.requests.isEmpty)
    }

    @Test func refreshesWhenLessThanAMinuteIsLeft() async throws {
        let server = StubServer { _ in .data("") }
        server.setHandler { request in
            #expect(request.path == "/auth/refresh")
            return .data(ContractSamples.authResult(accessExpiresAt: "2026-10-05T15:45:00.000Z", token: "access-2", refresh: "refresh-2"))
        }
        let (manager, tokens) = try await manager(server, expiresAt: now.addingTimeInterval(30))
        #expect(await manager.currentAccessToken() == "access-2")
        #expect(tokens.load()?.refreshToken == "refresh-2")
    }

    @Test func concurrentCallersShareOneRefresh() async throws {
        let server = StubServer { _ in .data("") }
        server.setHandler { _ in
            Thread.sleep(forTimeInterval: 0.2)
            return .data(ContractSamples.authResult(accessExpiresAt: "2026-10-05T15:45:00.000Z", token: "access-2", refresh: "refresh-2"))
        }
        let (manager, _) = try await manager(server, expiresAt: now.addingTimeInterval(10))
        let tokens = await withTaskGroup(of: String?.self) { group in
            for _ in 0..<5 { group.addTask { await manager.currentAccessToken() } }
            return await group.reduce(into: [String?]()) { $0.append($1) }
        }
        #expect(tokens.allSatisfy { $0 == "access-2" })
        #expect(server.requests.filter { $0.path == "/auth/refresh" }.count == 1)
    }

    @Test func rejectedRefreshSignsOut() async throws {
        let server = StubServer { _ in .error(401, code: "INVALID_REFRESH_TOKEN") }
        let (manager, tokens) = try await manager(server, expiresAt: now.addingTimeInterval(10))
        let events = Task { () -> SessionEvent? in
            for await event in manager.events {
                if case .signedOut = event { return event }
            }
            return nil
        }
        #expect(await manager.refresh() == .expired)
        #expect(await manager.isSignedIn == false)
        #expect(tokens.load() == nil)
        #expect(await events.value == SessionEvent.signedOut(.expired))
    }

    @Test func networkErrorKeepsTheSession() async throws {
        let server = StubServer { _ in .offline }
        let (manager, tokens) = try await manager(server, expiresAt: now.addingTimeInterval(10))
        #expect(await manager.refresh() == .unavailable)
        #expect(await manager.isSignedIn)
        #expect(tokens.load() != nil)
        // The stale token is still handed out, so requests fail as offline.
        #expect(await manager.currentAccessToken() == "access-1")
    }

    @Test func serverErrorKeepsTheSession() async throws {
        let server = StubServer { _ in .error(503, code: "INTERNAL_ERROR") }
        let (manager, _) = try await manager(server, expiresAt: now.addingTimeInterval(10))
        #expect(await manager.refresh() == .unavailable)
        #expect(await manager.isSignedIn)
    }

    @Test func clientRetriesOnceAfterA401() async throws {
        let calls = Mutex(0)
        let server = StubServer { _ in .data("") }
        server.setHandler { request in
            let count = calls.withLock { value in
                value += 1
                return value
            }
            return count == 1 ? .error(401, code: "UNAUTHORIZED") : .data("[]")
        }
        let refreshes = Mutex(0)
        let client = server.client(tokenProvider: { "token" }, onUnauthorized: {
            refreshes.withLock { $0 += 1 }
            return true
        })
        let people = try await client.send(APIRequest(.get, "/people"), as: [PersonDTO].self)
        #expect(people.isEmpty)
        #expect(refreshes.withLock { $0 } == 1)
        #expect(server.requests.allSatisfy { $0.headers["Authorization"] == "Bearer token" && $0.headers["X-Request-Id"] != nil })
    }
}
