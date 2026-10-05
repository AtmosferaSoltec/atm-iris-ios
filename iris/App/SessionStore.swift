//
//  SessionStore.swift
//  iris
//

import Foundation
import Observation

/// App-wide source of truth for the signed-in account.
@Observable
final class SessionStore {
    private(set) var session: UserSession?
    /// `true` until the saved session has been looked up at launch.
    private(set) var isRestoring = true

    private let authService: any AuthService
    /// Told when the app returns to the sign-in screen, so it can explain why.
    private let onSignedOut: (SignOutReason) -> Void

    init(authService: any AuthService, onSignedOut: @escaping (SignOutReason) -> Void = { _ in }) {
        self.authService = authService
        self.onSignedOut = onSignedOut
    }

    /// Restores the saved session (entering right away, even offline), then follows session changes
    /// until the calling task is cancelled.
    func run() async {
        if let restored = await authService.restoreSession() {
            session = restored
            isRestoring = false
            Task { await authService.resumeSession() }
        } else {
            isRestoring = false
        }
        for await event in authService.sessionEvents() {
            handle(event)
        }
    }

    func begin(_ session: UserSession) {
        self.session = session
    }

    func end(reason: SignOutReason) {
        guard session != nil else { return }
        session = nil
        onSignedOut(reason)
    }

    private func handle(_ event: SessionEvent) {
        switch event {
        case let .signedIn(session), let .updated(session):
            self.session = session
        case let .signedOut(reason):
            end(reason: reason)
        }
    }
}
