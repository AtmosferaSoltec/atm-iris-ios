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
        let sessionStore = SessionStore()
        _sessionStore = State(initialValue: sessionStore)
        _authViewModel = State(
            initialValue: AuthViewModel(
                authService: dependencies.authService,
                showcaseProvider: dependencies.showcaseProvider,
                onAuthenticated: { sessionStore.begin($0) }
            )
        )
    }

    var body: some View {
        ZStack {
            if let session = sessionStore.session {
                SignedInRoot(session: session, dependencies: dependencies) {
                    sessionStore.end()
                }
                .transition(.opacity)
            } else {
                AuthView(viewModel: authViewModel)
                    .transition(.opacity)
            }
        }
        .animation(IrisMotion.smooth, value: sessionStore.session)
        .preferredColorScheme(.dark)
        // V1 is Spanish-only; keep dates and times formatted accordingly.
        .environment(\.locale, Locale(identifier: "es"))
    }
}
