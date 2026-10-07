//
//  ProductionSmokeTests.swift
//  irisTests
//
//  The same end-to-end flow as `LiveAPIIntegrationTests`, against any server (the production API).
//  Skipped unless the account comes from the environment, so no credentials live in the repo:
//
//    TEST_RUNNER_IRIS_LIVE_URL=https://iris-api.atmosferast.com/api/v1 \
//    TEST_RUNNER_IRIS_LIVE_EMAIL=… TEST_RUNNER_IRIS_LIVE_PASSWORD=… \
//    xcodebuild test -scheme iris -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)'
//

import Foundation
import Testing
@testable import iris

nonisolated private enum LiveEnvironment {
    static let values = ProcessInfo.processInfo.environment
    static let url = values["IRIS_LIVE_URL"].flatMap(URL.init(string:))
    static let email = values["IRIS_LIVE_EMAIL"]
    static let password = values["IRIS_LIVE_PASSWORD"]
    static var isConfigured: Bool { url != nil && email != nil && password != nil }
}

@Suite(.serialized, .enabled(if: LiveEnvironment.isConfigured, "Falta IRIS_LIVE_URL, IRIS_LIVE_EMAIL o IRIS_LIVE_PASSWORD"))
struct ProductionSmokeTests {
    private struct Stack {
        let auth: LiveAuthService
        let store: LocalStore
        let sync: SyncEngine
        let data: LiveChurchData
        let client: APIClient
    }

    private func signedIn() async throws -> (Stack, UserSession) {
        let baseURL = try #require(LiveEnvironment.url)
        let publicClient = APIClient(baseURL: baseURL)
        let manager = AuthSessionManager(client: publicClient, tokenStore: InMemoryTokenStore(), sessionFile: nil)
        let client = APIClient(
            baseURL: baseURL,
            tokenProvider: { await manager.currentAccessToken() },
            onUnauthorized: { await manager.handleUnauthorized() }
        )
        let auth = LiveAuthService(manager: manager, publicClient: publicClient, client: client, deviceName: "Pruebas iPad")
        let session = try await auth.signIn(SignInCredentials(email: try #require(LiveEnvironment.email), password: try #require(LiveEnvironment.password)))
        let store = try LocalStore.inMemory()
        let changes = ChurchDataChanges()
        let outbox = Outbox(store: store, client: client)
        let sync = SyncEngine(store: store, client: client, outbox: outbox, changes: changes)
        return (Stack(auth: auth, store: store, sync: sync, data: LiveChurchData(store: store, outbox: outbox, sync: sync, changes: changes), client: client), session)
    }

    @Test func signInGivesAnAccountWithoutRolesOrChurchList() async throws {
        let (_, session) = try await signedIn()
        #expect(!session.church.name.isEmpty)
        #expect(session.churches.isEmpty)
        #expect(session.permissions == Set(Permission.allCases))
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

    @Test func personAddedLocallyReachesTheAPIOnceAndIsRemoved() async throws {
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

    /// With the Bible switched off for all of Iris (`system_features`) every Bible route answers 404
    /// with a clear message; once it is on again, the iPad downloads it and reads John 3:16.
    @Test func bibleIsReadableOrSwitchedOffForEveryone() async throws {
        let (stack, _) = try await signedIn()
        do {
            _ = try await stack.client.send(APIRequest(.get, "/bible/translations"), as: [BibleTranslationDTO].self)
        } catch let error as APIError {
            #expect(error.message == "La Biblia no está disponible por ahora.")
            return
        }
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
