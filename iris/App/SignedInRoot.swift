//
//  SignedInRoot.swift
//  iris
//

import SwiftUI

/// Navigation state for a signed-in session.
@Observable
final class SignedInNavigator {
    enum Route: Equatable {
        case home, console(ServiceType), modules, services, people, times
    }

    var route: Route = .home

    func navigate(to route: Route) {
        self.route = route
    }

    func returnHome() {
        route = .home
    }
}

/// Home ⇄ console and the church settings screens.
/// Home's view model lives for the whole session so returning is instant.
struct SignedInRoot: View {
    private let session: UserSession
    private let dependencies: AppDependencies
    private let onSignOut: () -> Void

    @State private var navigator: SignedInNavigator
    @State private var homeViewModel: HomeViewModel

    init(session: UserSession, dependencies: AppDependencies, onSignOut: @escaping () -> Void) {
        self.session = session
        self.dependencies = dependencies
        self.onSignOut = onSignOut

        let navigator = SignedInNavigator()
        _navigator = State(initialValue: navigator)
        _homeViewModel = State(
            initialValue: HomeViewModel(
                session: session,
                moduleSettings: dependencies.moduleSettings,
                serviceTypes: dependencies.serviceTypes,
                people: dependencies.people,
                timeRecords: dependencies.timeRecords,
                libraryRepository: dependencies.libraryRepository,
                displayOutput: dependencies.displayOutput,
                onNavigate: { navigator.navigate(to: $0) }
            )
        )
    }

    var body: some View {
        ZStack {
            switch navigator.route {
            case .home:
                HomeView(viewModel: homeViewModel, onSignOut: onSignOut)
                    .transition(.opacity)
            case let .console(serviceType):
                LiveConsoleScreen(
                    session: session,
                    serviceType: serviceType,
                    modules: homeViewModel.modules,
                    people: homeViewModel.people,
                    dependencies: dependencies,
                    onExit: { navigator.returnHome() },
                    onOpenTimes: { navigator.navigate(to: .times) },
                    onSignOut: onSignOut
                )
                .transition(.opacity)
            case .modules:
                secondaryScreen(String(localized: "Módulos")) {
                    ModulesView(viewModel: ModulesViewModel(moduleSettings: dependencies.moduleSettings))
                }
                    .transition(.opacity)
            case .services:
                secondaryScreen(String(localized: "Servicios")) {
                    ServiceTypesView(
                        viewModel: ServiceTypesViewModel(
                            serviceTypes: dependencies.serviceTypes,
                            people: dependencies.people,
                            moduleSettings: dependencies.moduleSettings
                        )
                    )
                }
                    .transition(.opacity)
            case .people:
                secondaryScreen(String(localized: "Personas")) {
                    PeopleView(viewModel: PeopleViewModel(people: dependencies.people, timeRecords: dependencies.timeRecords))
                }
                    .transition(.opacity)
            case .times:
                secondaryScreen(String(localized: "Tiempos")) {
                    TimesView(
                        viewModel: TimesViewModel(
                            timeRecords: dependencies.timeRecords,
                            serviceTypes: dependencies.serviceTypes,
                            people: dependencies.people
                        )
                    )
                }
                    .transition(.opacity)
            }
        }
        .animation(IrisMotion.smooth, value: navigator.route)
    }

    /// Top bar with "‹ Inicio" and the screen title, over the ambient background.
    private func secondaryScreen(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            ConsoleTopBar(
                title: title,
                display: homeViewModel.display,
                churchName: session.churchName,
                initials: homeViewModel.accountInitials,
                onExit: { navigator.returnHome() },
                onSignOut: { onSignOut() }
            )
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { IrisBackground(isAnimated: false) }
    }
}
