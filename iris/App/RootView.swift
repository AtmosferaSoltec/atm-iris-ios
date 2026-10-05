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
    }

    var body: some View {
        ZStack {
            if let session = sessionStore.session {
                SignedInRoot(
                    session: session,
                    dependencies: dependencies,
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
        }
        .animation(IrisMotion.smooth, value: sessionStore.session)
        .task { await sessionStore.run() }
        .preferredColorScheme(.dark)
        // V1 is Spanish-only; keep dates and times formatted accordingly.
        .environment(\.locale, Locale(identifier: "es"))
    }
}
