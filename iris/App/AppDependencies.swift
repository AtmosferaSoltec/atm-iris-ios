//
//  AppDependencies.swift
//  iris
//

import Foundation

/// Composition root. Swap `.mock` for a live container when the API arrives.
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
    let serviceTypes: any ServiceTypeRepository
    let people: any PeopleRepository
    let timeRecords: any TimeRecordRepository

    static let mock: AppDependencies = {
        // One store for the whole run, shared by the four church repositories.
        let churchStore = InMemoryChurchStore()
        return AppDependencies(
            authService: MockAuthService(),
            showcaseProvider: MockShowcaseContentProvider(),
            servicePlanRepository: MockServicePlanRepository(),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: MockDisplayOutputService(),
            moduleSettings: MockModuleSettingsRepository(store: churchStore),
            serviceTypes: MockServiceTypeRepository(store: churchStore),
            people: MockPeopleRepository(store: churchStore),
            timeRecords: MockTimeRecordRepository(store: churchStore)
        )
    }()
}
