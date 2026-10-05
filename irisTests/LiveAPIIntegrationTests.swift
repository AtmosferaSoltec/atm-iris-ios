//
//  LiveAPIIntegrationTests.swift
//  irisTests
//
//  End-to-end against the local API (`pnpm start:dev` in ../atm-iris-api). Skipped when it is not running.
//

import Foundation
import Testing
@testable import iris

nonisolated private let apiBaseURL = URL(string: "http://localhost:3020/api/v1")!

nonisolated private var isAPIRunning: Bool {
    var request = URLRequest(url: apiBaseURL.appending(path: "health"))
    request.timeoutInterval = 2
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var isUp = false
    URLSession.shared.dataTask(with: request) { _, response, _ in
        isUp = (response as? HTTPURLResponse)?.statusCode == 200
        semaphore.signal()
    }.resume()
    semaphore.wait()
    return isUp
}

@Suite(.serialized, .enabled(if: isAPIRunning, "La API local no está corriendo"))
struct LiveAPIIntegrationTests {
    private struct Stack {
        let auth: LiveAuthService
        let store: LocalStore
        let sync: SyncEngine
        let data: LiveChurchData
        let client: APIClient
    }

    private func signedIn() async throws -> (Stack, UserSession) {
        let publicClient = APIClient(baseURL: apiBaseURL)
        let manager = AuthSessionManager(client: publicClient, tokenStore: InMemoryTokenStore(), sessionFile: nil)
        let client = APIClient(
            baseURL: apiBaseURL,
            tokenProvider: { await manager.currentAccessToken() },
            onUnauthorized: { await manager.handleUnauthorized() }
        )
        let auth = LiveAuthService(manager: manager, publicClient: publicClient, client: client, deviceName: "Pruebas iPad")
        let session = try await auth.signIn(SignInCredentials(email: "pastor@vidanueva.org", password: "vidanueva123"))
        let store = try LocalStore.inMemory()
        let changes = ChurchDataChanges()
        let outbox = Outbox(store: store, client: client)
        let sync = SyncEngine(store: store, client: client, outbox: outbox, changes: changes)
        return (Stack(auth: auth, store: store, sync: sync, data: LiveChurchData(store: store, outbox: outbox, sync: sync, changes: changes), client: client), session)
    }

    @Test func wrongPasswordShowsTheAPIMessage() async throws {
        let publicClient = APIClient(baseURL: apiBaseURL)
        let auth = LiveAuthService(
            manager: AuthSessionManager(client: publicClient, tokenStore: InMemoryTokenStore(), sessionFile: nil),
            publicClient: publicClient, client: publicClient, deviceName: "Pruebas iPad"
        )
        do {
            _ = try await auth.signIn(SignInCredentials(email: "pastor@vidanueva.org", password: "incorrecta-123"))
            Issue.record("El login con contraseña incorrecta no falló")
        } catch let error as AuthError {
            #expect(error.code == "INVALID_CREDENTIALS")
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }

    @Test func firstSyncCopiesTheChurch() async throws {
        let (stack, session) = try await signedIn()
        await stack.sync.start(session: session)
        #expect(stack.sync.initialSync == .ready)

        let serverPeople = try await stack.client.send(APIRequest(.get, "/people"), as: [PersonDTO].self)
        let localPeople = try await LivePeopleRepository(data: stack.data).people()
        #expect(Set(localPeople.map(\.id.apiString)) == Set(serverPeople.map { $0.id.lowercased() }))

        let serverTypes = try await stack.client.send(APIRequest(.get, "/service-types"), as: [ServiceTypeDTO].self)
        #expect(try await LiveServiceTypeRepository(data: stack.data).serviceTypes().count == serverTypes.count)

        let songs = try await stack.client.sendPage(APIRequest(.get, "/songs", query: [URLQueryItem(name: "limit", value: "1")]), of: SongSummaryDTO.self)
        let localSongs = try await LiveLibraryRepository(data: stack.data, cache: MediaCache(client: stack.client, downloader: .shared)).lyrics()
        #expect(localSongs.count == songs.meta.total)
    }

    @Test func personAddedLocallyReachesTheAPIOnce() async throws {
        let (stack, session) = try await signedIn()
        await stack.sync.start(session: session)
        let people = LivePeopleRepository(data: stack.data)
        let person = try await people.add(name: "Prueba iPad \(Int.random(in: 1000...9999))")
        await stack.sync.syncNow(reason: .manual)

        #expect(await stack.store.pendingCount() == 0)
        let onServer = try await stack.client.send(APIRequest(.get, "/people"), as: [PersonDTO].self)
        #expect(onServer.filter { $0.id.lowercased() == person.id.apiString }.count == 1)

        try await people.delete(person.id)
        await stack.sync.syncNow(reason: .manual)
        let afterDelete = try await stack.client.send(APIRequest(.get, "/people"), as: [PersonDTO].self)
        #expect(!afterDelete.contains { $0.id.lowercased() == person.id.apiString })
    }

    @Test func bibleDownloadsAndReadsJohn316() async throws {
        let (stack, _) = try await signedIn()
        let folder = URL.temporaryDirectory.appending(path: "bible-\(UUID().uuidString)")
        let bible = LiveBibleRepository(store: BibleStore(client: stack.client, folder: folder))
        await bible.prepare()
        let verses = try await bible.verses(bookID: "JHN", chapter: 3)
        #expect(verses[15].text.hasPrefix("Porque de tal manera amó Dios al mundo"))
        #expect(try await bible.books().count == 66)
        try? FileManager.default.removeItem(at: folder)
    }

    @Test func signOutEndsTheSessionOnTheAPI() async throws {
        let (stack, _) = try await signedIn()
        await stack.auth.signOut()
        await #expect(throws: APIError.self) {
            _ = try await stack.client.send(APIRequest(.get, "/auth/me"), as: SessionViewDTO.self)
        }
    }
}
