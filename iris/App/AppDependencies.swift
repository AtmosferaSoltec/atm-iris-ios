//
//  AppDependencies.swift
//  iris
//

import Foundation
import UIKit

/// Composition root: `.live` talks to the API, `.mock` keeps previews, tests and `-IrisDataMode mock` offline.
struct AppDependencies {
    let authService: any AuthService
    let showcaseProvider: any ShowcaseContentProvider
    let servicePlanRepository: any ServicePlanRepository
    let backgroundRepository: any BackgroundRepository
    let bibleRepository: any BibleRepository
    let libraryRepository: any LibraryRepository
    let mediaPlayback: any MediaPlaybackService
    let displayOutput: any DisplayOutputService
    let moduleSettings: any ModuleSettingsRepository
    let projectionSettings: any ProjectionSettingsRepository
    let serviceTypes: any ServiceTypeRepository
    let people: any PeopleRepository
    let timeRecords: any TimeRecordRepository
    let sync: any SyncService
    let appVersions: any AppVersionService

    /// The container for this launch.
    static func make(_ config: AppConfig) -> AppDependencies {
        switch config.dataMode {
        case .mock: .mock
        case .live: .live(config)
        }
    }

    static let mock: AppDependencies = {
        // One store for the whole run, shared by the four church repositories.
        let churchStore = InMemoryChurchStore()
        return AppDependencies(
            authService: MockAuthService(),
            showcaseProvider: StaticShowcaseContentProvider(),
            servicePlanRepository: MockServicePlanRepository(),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: MockDisplayOutputService(),
            moduleSettings: MockModuleSettingsRepository(store: churchStore),
            projectionSettings: MockProjectionSettingsRepository(store: churchStore),
            serviceTypes: MockServiceTypeRepository(store: churchStore),
            people: MockPeopleRepository(store: churchStore),
            timeRecords: MockTimeRecordRepository(store: churchStore),
            sync: MockSyncService(),
            appVersions: MockAppVersionService()
        )
    }()

    static func live(_ config: AppConfig) -> AppDependencies {
        // The manager refreshes through a client without tokens; everything else uses the authorized one.
        let publicClient = APIClient(baseURL: config.apiBaseURL)
        let sessionManager = AuthSessionManager(client: publicClient, tokenStore: KeychainTokenStore())
        let client = APIClient(
            baseURL: config.apiBaseURL,
            tokenProvider: { await sessionManager.currentAccessToken() },
            onUnauthorized: { await sessionManager.handleUnauthorized() }
        )
        let authService = LiveAuthService(
            manager: sessionManager,
            publicClient: publicClient,
            client: client,
            deviceName: UIDevice.current.name
        )

        let localStore = Self.openLocalStore()
        let changes = ChurchDataChanges()
        let outbox = Outbox(store: localStore, client: client)
        let sync = SyncEngine(store: localStore, client: client, outbox: outbox, changes: changes)
        sync.onForbidden = { await authService.reloadSession() }

        let data = LiveChurchData(store: localStore, outbox: outbox, sync: sync, changes: changes)

        // Music used to be copied by hand into Documents/Música; it now comes from the web (contract §11).
        // Nothing reads that folder any more and Files no longer shows it, so it only took space.
        try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: "Música", directoryHint: .isDirectory))

        // Media files follow each sync, in the background. What is in the plan downloads now, so
        // the console opens with it ready — whether the web, this iPad or another console added it.
        let mediaCache = MediaCache(client: client, downloader: .shared)
        Task {
            await mediaCache.setHandlers(
                onChange: { Task { @MainActor in changes.publish([.media]) } },
                onLowStorage: { isLow in
                    Task { @MainActor in
                        sync.storageWarning = isLow
                            ? String(localized: "Queda poco espacio en el iPad: los videos se descargarán cuando liberes espacio.")
                            : nil
                    }
                }
            )
        }
        sync.afterSync.append {
            guard let churchID = await localStore.churchID() else { return }
            let assets = await localStore.all(.media, as: MediaAssetDTO.self)
            let planIDs = await Self.planFileIDs(in: localStore)
            Task {
                await mediaCache.use(churchID: churchID)
                await mediaCache.ensureDownloaded(assets, requesting: planIDs)
            }
        }
        sync.onDiscard.append { await mediaCache.clear() }

        // The Bible is out for now (contract §13): nothing downloads it; the picker is never offered.
        let bibleStore = BibleStore(client: client)
        let library = LiveLibraryRepository(data: data, cache: mediaCache)
        return AppDependencies(
            authService: authService,
            showcaseProvider: StaticShowcaseContentProvider(),
            servicePlanRepository: LiveServicePlanRepository(data: data, library: library),
            backgroundRepository: LiveBackgroundRepository(library: library),
            bibleRepository: LiveBibleRepository(store: bibleStore),
            libraryRepository: library,
            mediaPlayback: LiveMediaPlaybackService(),
            displayOutput: LiveDisplayOutputService(),
            moduleSettings: LiveModuleSettingsRepository(data: data),
            projectionSettings: LiveProjectionSettingsRepository(data: data),
            serviceTypes: LiveServiceTypeRepository(data: data),
            people: LivePeopleRepository(data: data),
            timeRecords: LiveTimeRecordRepository(data: data),
            sync: sync,
            appVersions: LiveAppVersionService(
                client: publicClient,
                currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
            )
        )
    }

    /// The files the plan needs (contract §15): its images and videos, and the tracks of its songs.
    private static func planFileIDs(in store: LocalStore) async -> [String] {
        let plan = await store.all(.servicePlan, as: ServicePlanItemDTO.self)
        guard !plan.isEmpty else { return [] }
        let songIDs = Set(plan.filter { $0.kind == .song }.map(\.refId))
        let tracks = await store.all(.songs, as: SongDTO.self)
            .filter { songIDs.contains($0.id) }
            .compactMap { $0.audio?.id }
        return plan.filter { $0.kind == .media }.map(\.refId) + tracks
    }

    /// The on-disk copy; if it cannot be opened (corrupt or full disk), a temporary one so the app still starts.
    private static func openLocalStore() -> LocalStore {
        if let store = try? LocalStore.onDisk() { return store }
        guard let store = try? LocalStore.inMemory() else {
            fatalError("SwiftData no pudo crear ni siquiera una copia en memoria.")
        }
        return store
    }
}
