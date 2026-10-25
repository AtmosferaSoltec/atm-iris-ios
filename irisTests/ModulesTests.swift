//
//  ModulesTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// Iris has no modules anymore (contract §6): the console offers everything, and the Bible is out for now.
struct ModulesTests {
    private func console() -> LiveConsoleViewModel {
        let viewModel = LiveConsoleViewModel(
            session: .preview,
            modules: .everything,
            servicePlanRepository: MockServicePlanRepository(latency: .zero),
            projectionSettings: MockProjectionSettingsRepository(store: InMemoryChurchStore(), latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(latency: .zero),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: MockDisplayOutputService(),
            serviceTypes: MockServiceTypeRepository(store: InMemoryChurchStore(), latency: .zero),
            peopleRepository: MockPeopleRepository(store: InMemoryChurchStore(), latency: .zero),
            timeRecords: MockTimeRecordRepository(store: InMemoryChurchStore(), latency: .zero)
        )
        viewModel.apply(plan: MockServicePlanRepository.sample, backgrounds: MockBackgroundRepository.sample, display: nil)
        return viewModel
    }

    @Test func consoleOffersSongsAndMultimedia() throws {
        let viewModel = console()

        viewModel.presentAddToService()
        #expect(viewModel.addSheet?.tabs == AddToServiceViewModel.Tab.allCases)

        let video = try #require(viewModel.items.first { $0.kind == .video })
        viewModel.selectItem(video.id)
        viewModel.presentSelectedMedia()
        #expect(viewModel.playback?.itemID == video.id)
    }

    @Test func theBibleIsNotOffered() {
        let viewModel = console()

        #expect(viewModel.showsBible == false)
        viewModel.presentBible()
        #expect(viewModel.biblePicker == nil)
    }
}
