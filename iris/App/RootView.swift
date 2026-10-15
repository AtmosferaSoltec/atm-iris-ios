//
//  RootView.swift
//  iris
//

import SwiftUI

/// Switches between the auth flow and the signed-in experience.
struct RootView: View {
    private let dependencies: AppDependencies

    @State private var sessionStore: SessionStore
    @State private var authViewModel: AuthViewModel
    @State private var updateGate: AppUpdateGate
    @Environment(\.scenePhase) private var scenePhase

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        // The store tells the sign-in screen why it is back (an expired session shows a banner).
        var onSignedOut: (SignOutReason) -> Void = { _ in }
        let sessionStore = SessionStore(authService: dependencies.authService) { onSignedOut($0) }
        let authViewModel = AuthViewModel(
            authService: dependencies.authService,
            showcaseProvider: dependencies.showcaseProvider,
            onAuthenticated: { sessionStore.begin($0) }
        )
        onSignedOut = { authViewModel.presentSignOut(reason: $0) }
        _sessionStore = State(initialValue: sessionStore)
        _authViewModel = State(initialValue: authViewModel)
        _updateGate = State(initialValue: AppUpdateGate(service: dependencies.appVersions))
    }

    var body: some View {
        ZStack {
            if let session = sessionStore.session {
                SignedInRoot(
                    session: session,
                    dependencies: dependencies,
                    updateGate: updateGate,
                    onSignedOut: { sessionStore.end(reason: .requested) },
                    onSwitched: { sessionStore.begin($0) }
                )
                // Another church is another world: rebuild every screen for it.
                .id(session.church.id)
                .transition(.opacity)
            } else if !sessionStore.isRestoring {
                AuthView(viewModel: authViewModel)
                    .transition(.opacity)
            }

            // Blocks everything until the new version is installed (never while a service is running).
            if let notice = updateGate.visibleNotice {
                UpdateRequiredView(notice: notice)
                    .transition(.opacity)
            }
        }
        .animation(IrisMotion.smooth, value: sessionStore.session)
        .animation(IrisMotion.smooth, value: updateGate.visibleNotice)
        .onChange(of: sessionStore.session) { _, session in
            // Signing out from the console must not leave the notice hidden on the sign-in screen.
            if session == nil { updateGate.isServiceLive = false }
        }
        .task { await sessionStore.run() }
        .task(id: scenePhase) {
            if scenePhase == .active { await updateGate.refresh() }
        }
        .preferredColorScheme(.dark)
        // V1 is Spanish-only; keep dates and times formatted accordingly.
        .environment(\.locale, Locale(identifier: "es"))
    }
}
