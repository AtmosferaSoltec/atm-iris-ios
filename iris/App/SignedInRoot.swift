//
//  SignedInRoot.swift
//  iris
//

import SwiftUI

/// Navigation state for a signed-in session.
@Observable
final class SignedInNavigator {
    enum Route: Equatable {
        case home, console(ServiceType), library, modules, services, people, times
    }

    private(set) var route: Route = .home

    /// Paused while a service runs: the console works with the copy it had when it started.
    private let sync: any SyncService

    init(sync: any SyncService) {
        self.sync = sync
    }

    func navigate(to route: Route) {
        if case .console = route {
            sync.suspend()
        } else {
            sync.resume()
        }
        self.route = route
    }

    func returnHome() {
        navigate(to: .home)
    }
}

/// Home ⇄ console and the church settings screens.
/// Home's view model lives for the whole session so returning is instant.
struct SignedInRoot: View {
    private let session: UserSession
    private let dependencies: AppDependencies
    private let updateGate: AppUpdateGate

    @State private var context: SessionContext
    @State private var navigator: SignedInNavigator
    @State private var homeViewModel: HomeViewModel
    @State private var account: AccountViewModel
    @State private var showsWelcome: Bool

    init(
        session: UserSession,
        dependencies: AppDependencies,
        updateGate: AppUpdateGate,
        onSignedOut: @escaping () -> Void,
        onSwitched: @escaping (UserSession) -> Void
    ) {
        self.session = session
        self.dependencies = dependencies
        self.updateGate = updateGate

        _showsWelcome = State(initialValue: !Self.welcomeSeen(by: session.userID))
        let context = SessionContext(session)
        _context = State(initialValue: context)
        let navigator = SignedInNavigator(sync: dependencies.sync)
        _navigator = State(initialValue: navigator)
        _account = State(initialValue: AccountViewModel(
            context: context,
            authService: dependencies.authService,
            sync: dependencies.sync,
            onSignedOut: onSignedOut,
            onSwitched: onSwitched
        ))
        _homeViewModel = State(
            initialValue: HomeViewModel(
                session: context,
                moduleSettings: dependencies.moduleSettings,
                serviceTypes: dependencies.serviceTypes,
                people: dependencies.people,
                timeRecords: dependencies.timeRecords,
                libraryRepository: dependencies.libraryRepository,
                displayOutput: dependencies.displayOutput,
                sync: dependencies.sync,
                reloadSession: { await dependencies.authService.reloadSession() },
                onNavigate: { navigator.navigate(to: $0) }
            )
        )
    }

    var body: some View {
        ZStack {
            switch navigator.route {
            case .home:
                HomeView(viewModel: homeViewModel, account: account)
                    .transition(.opacity)
            case let .console(serviceType):
                LiveConsoleScreen(
                    session: context,
                    serviceType: serviceType,
                    modules: homeViewModel.modules,
                    people: homeViewModel.people,
                    dependencies: dependencies,
                    onExit: { navigator.returnHome() },
                    onOpenTimes: { navigator.navigate(to: .times) },
                    account: account
                )
                .transition(.opacity)
            case .library:
                secondaryScreen(String(localized: "Biblioteca")) {
                    AddToServiceView(
                        viewModel: AddToServiceViewModel(
                            repository: dependencies.libraryRepository,
                            tabs: homeViewModel.modules.multimedia ? AddToServiceViewModel.Tab.allCases : [.lyrics],
                            mode: .browse
                        )
                    )
                }
                    .transition(.opacity)
            case .modules:
                secondaryScreen(String(localized: "Configuración")) {
                    ModulesView(
                        viewModel: ModulesViewModel(
                            moduleSettings: dependencies.moduleSettings,
                            projectionSettings: dependencies.projectionSettings,
                            backgroundRepository: dependencies.backgroundRepository,
                            session: context
                        )
                    )
                }
                    .transition(.opacity)
            case .services:
                secondaryScreen(String(localized: "Servicios")) {
                    ServiceTypesView(
                        viewModel: ServiceTypesViewModel(
                            serviceTypes: dependencies.serviceTypes,
                            people: dependencies.people,
                            moduleSettings: dependencies.moduleSettings,
                            session: context
                        )
                    )
                }
                    .transition(.opacity)
            case .people:
                secondaryScreen(String(localized: "Personas")) {
                    PeopleView(viewModel: PeopleViewModel(people: dependencies.people, timeRecords: dependencies.timeRecords, session: context))
                }
                    .transition(.opacity)
            case .times:
                secondaryScreen(String(localized: "Tiempos")) {
                    TimesView(
                        viewModel: TimesViewModel(
                            timeRecords: dependencies.timeRecords,
                            serviceTypes: dependencies.serviceTypes,
                            people: dependencies.people,
                            session: context
                        )
                    )
                }
                    .transition(.opacity)
            }
        }
        .overlay {
            if showsWelcome {
                WelcomeView {
                    UserDefaults.standard.set(true, forKey: Self.welcomeKey(for: session.userID))
                    showsWelcome = false
                }
                .transition(.opacity)
            }
        }
        .animation(IrisMotion.smooth, value: showsWelcome)
        .animation(IrisMotion.smooth, value: navigator.route)
        .onChange(of: navigator.route, initial: true) { _, route in
            if case .console = route { updateGate.isServiceLive = true } else { updateGate.isServiceLive = false }
        }
        .task { await dependencies.sync.start(session: session) }
        // Role and permission changes reach every open screen without rebuilding them.
        .onChange(of: session) { _, session in context.session = session }
    }

    /// The welcome screen is shown once per person on this iPad.
    private static func welcomeKey(for userID: UUID) -> String {
        "welcomeSeen.\(userID.uuidString)"
    }

    private static func welcomeSeen(by userID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: welcomeKey(for: userID))
    }

    /// Top bar with "‹ Inicio" and the screen title, over the ambient background.
    private func secondaryScreen(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            ConsoleTopBar(
                title: title,
                display: homeViewModel.display,
                account: account,
                sync: dependencies.sync,
                onExit: { navigator.returnHome() }
            )
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { IrisBackground(isAnimated: false) }
    }
}
