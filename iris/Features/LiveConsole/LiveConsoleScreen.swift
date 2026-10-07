//
//  LiveConsoleScreen.swift
//  iris
//

import SwiftUI

/// Owns the console view model for the lifetime of a signed-in session.
struct LiveConsoleScreen: View {
    @State private var viewModel: LiveConsoleViewModel
    private let onExit: () -> Void
    private let onOpenTimes: () -> Void
    private let account: AccountViewModel

    init(
        session: SessionContext,
        serviceType: ServiceType?,
        modules: ChurchModules,
        people: [Person],
        dependencies: AppDependencies,
        onExit: @escaping () -> Void,
        onOpenTimes: @escaping () -> Void,
        account: AccountViewModel
    ) {
        _viewModel = State(
            initialValue: LiveConsoleViewModel(
                session: session,
                serviceType: serviceType,
                modules: modules,
                people: people,
                servicePlanRepository: dependencies.servicePlanRepository,
                projectionSettings: dependencies.projectionSettings,
                backgroundRepository: dependencies.backgroundRepository,
                bibleRepository: dependencies.bibleRepository,
                libraryRepository: dependencies.libraryRepository,
                mediaPlayback: dependencies.mediaPlayback,
                displayOutput: dependencies.displayOutput,
                serviceTypes: dependencies.serviceTypes,
                peopleRepository: dependencies.people,
                timeRecords: dependencies.timeRecords
            )
        )
        self.onExit = onExit
        self.onOpenTimes = onOpenTimes
        self.account = account
    }

    var body: some View {
        LiveConsoleView(viewModel: viewModel, onExit: onExit, onOpenTimes: onOpenTimes, account: account)
            // The iPad must not lock in the middle of a service: the TV would go dark with it.
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
