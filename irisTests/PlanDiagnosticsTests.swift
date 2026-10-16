//
//  PlanDiagnosticsTests.swift
//  irisTests
//
//  "What would the iPad show when a service starts?" Signs in against a real server, syncs into an in-memory
//  copy (read-only: nothing is written and no media is downloaded) and prints the plan the console would load:
//  what the server has, what the iPad resolves, and what is lost on the way. Skipped without credentials:
//
//    TEST_RUNNER_IRIS_LIVE_URL=https://iris-api.atmosferast.com/api/v1 \
//    TEST_RUNNER_IRIS_LIVE_EMAIL=… TEST_RUNNER_IRIS_LIVE_PASSWORD=… TEST_RUNNER_IRIS_REPORT_PATH=/tmp/plan.txt \
//    xcodebuild test -scheme iris -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
//      -only-testing:irisTests/PlanDiagnosticsTests
//

import Foundation
import Testing
@testable import iris

nonisolated private enum DiagnosticsEnvironment {
    static let values = ProcessInfo.processInfo.environment
    static let url = values["IRIS_LIVE_URL"].flatMap(URL.init(string:))
    static let email = values["IRIS_LIVE_EMAIL"]
    static let password = values["IRIS_LIVE_PASSWORD"]
    static var isConfigured: Bool { url != nil && email != nil && password != nil }
}

@Suite(.serialized, .enabled(if: DiagnosticsEnvironment.isConfigured, "Falta IRIS_LIVE_URL, IRIS_LIVE_EMAIL o IRIS_LIVE_PASSWORD"))
struct PlanDiagnosticsTests {
    @Test func theConsoleLoadsEverythingTheWebPutInThePlan() async throws {
        let baseURL = try #require(DiagnosticsEnvironment.url)
        let publicClient = APIClient(baseURL: baseURL)
        let manager = AuthSessionManager(client: publicClient, tokenStore: InMemoryTokenStore(), sessionFile: nil)
        let client = APIClient(
            baseURL: baseURL,
            tokenProvider: { await manager.currentAccessToken() },
            onUnauthorized: { await manager.handleUnauthorized() }
        )
        let auth = LiveAuthService(manager: manager, publicClient: publicClient, client: client, deviceName: "Diagnóstico iPad")
        let session = try await auth.signIn(SignInCredentials(email: try #require(DiagnosticsEnvironment.email), password: try #require(DiagnosticsEnvironment.password)))
        defer { Task { await auth.signOut() } }

        let store = try LocalStore.inMemory()
        let changes = ChurchDataChanges()
        let outbox = Outbox(store: store, client: client)
        let sync = SyncEngine(store: store, client: client, outbox: outbox, changes: changes)
        let data = LiveChurchData(store: store, outbox: outbox, sync: sync, changes: changes)
        await sync.start(session: session)
        #expect(sync.initialSync == .ready)

        let library = LiveLibraryRepository(data: data, cache: MediaCache(client: client, downloader: .shared))
        let church = await store.all(.church, as: ChurchDTO.self).first
        let entries = await store.all(.servicePlan, as: ServicePlanItemDTO.self)
        let plan = try await LiveServicePlanRepository(data: data, library: library).currentService()
        let lyrics = try await library.lyrics()
        let music = await library.music()
        let uploaded = await library.uploadedMedia()

        var report = ["", "=== DIAGNÓSTICO DEL PLAN (lo que vería el iPad) ==="]
        report.append("Iglesia: \(church?.name ?? "?") · módulos: \(String(describing: church?.modules))")
        report.append("Copia local: \(lyrics.count) letras, \(music.count) músicas, \(uploaded.count) multimedia")
        report.append("Plan en el servidor/copia local: \(entries.count) elementos")
        for entry in entries { report.append("  · \(entry.kind) \(entry.refId.prefix(8))… posición \(entry.position)") }
        report.append("Lo que la consola carga: \(plan.items.count) elementos")
        for item in plan.items { report.append("  ✓ \(item.kind) · \(item.title)") }
        let multimediaOn = church?.modules.multimedia ?? true
        if !multimediaOn {
            let hidden = plan.items.filter { [.music, .image, .video].contains($0.kind) }.count
            report.append("⚠︎ Multimedia apagada: la consola ocultaría \(hidden) elemento(s) (música, imagen o video)")
        }
        let lost = entries.count - plan.items.count
        if lost > 0 { report.append("⚠︎ \(lost) elemento(s) del plan no se resolvieron en la copia local") }
        report.append("=== FIN ===")
        let text = report.joined(separator: "\n")
        print(text)
        // xcodebuild hides the test's stdout; this writes it where it can be read (the simulator shares the Mac's disk).
        if let path = DiagnosticsEnvironment.values["IRIS_REPORT_PATH"] { try? text.write(toFile: path, atomically: true, encoding: .utf8) }

        #expect(plan.items.count == entries.count, "El iPad perdió elementos del plan al resolverlos")
    }
}
