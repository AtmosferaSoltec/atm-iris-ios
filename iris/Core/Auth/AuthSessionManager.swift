//
//  AuthSessionManager.swift
//  iris
//

import Foundation
import os

/// Why the app went back to the sign-in screen.
nonisolated enum SignOutReason: Equatable, Sendable {
    /// The person signed out.
    case requested
    /// The refresh token stopped working (expired, revoked, or the session was closed elsewhere).
    case expired
}

/// Changes of the signed-in session, observed by `SessionStore`.
nonisolated enum SessionEvent: Equatable, Sendable {
    case signedIn(UserSession)
    case updated(UserSession)
    case signedOut(SignOutReason)
}

/// Owner of the tokens (API contract §4.1): hands out fresh access tokens, refreshes them with a
/// single request in flight, and keeps the last `SessionView` on disk so the app opens without network.
actor AuthSessionManager {
    nonisolated enum RefreshOutcome: Equatable, Sendable {
        case refreshed
        /// No network or a server error: the session stays, work continues offline.
        case unavailable
        /// The refresh token no longer works: the session is over.
        case expired
    }

    /// Refresh this long before the access token expires.
    static let refreshMargin: TimeInterval = 60

    nonisolated let events: AsyncStream<SessionEvent>
    private let continuation: AsyncStream<SessionEvent>.Continuation

    private let client: APIClient
    private let tokenStore: any TokenStore
    private let sessionFile: URL?
    private let now: @Sendable () -> Date

    private var tokens: StoredTokens?
    private var sessionView: SessionViewDTO?
    private var refreshTask: Task<RefreshOutcome, Never>?

    private static let logger = Logger(subsystem: "com.atmosfera.iris", category: "auth")

    /// - Parameters:
    ///   - client: a client **without** token handling, used for the public refresh endpoint.
    ///   - sessionFile: where the last `SessionView` is kept; `nil` keeps it in memory only.
    init(
        client: APIClient,
        tokenStore: any TokenStore,
        sessionFile: URL? = AuthSessionManager.defaultSessionFile,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.client = client
        self.tokenStore = tokenStore
        self.sessionFile = sessionFile
        self.now = now
        (events, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    }

    nonisolated static var defaultSessionFile: URL {
        URL.applicationSupportDirectory.appending(path: "session.json")
    }

    // MARK: Session

    var currentSession: UserSession? {
        sessionView.flatMap { try? UserSession($0) }
    }

    var isSignedIn: Bool { tokens != nil }

    /// Loads the saved session. Returns it right away, even without network; the caller refreshes afterwards.
    func restore() -> UserSession? {
        guard let stored = tokenStore.load(), stored.refreshTokenExpiresAt > now() else {
            clearLocalState()
            return nil
        }
        guard let sessionFile, let data = try? Data(contentsOf: sessionFile),
              let view = try? JSONCoding.decoder.decode(SessionViewDTO.self, from: data),
              let session = try? UserSession(view) else {
            // Tokens without a saved session view: the next refresh brings it back.
            tokens = stored
            return nil
        }
        tokens = stored
        sessionView = view
        return session
    }

    /// Installs the result of sign-in, sign-up, switch-church or accepting an invitation.
    @discardableResult
    func establish(_ result: AuthResultDTO) throws -> UserSession {
        let session = try UserSession(result.sessionView)
        install(result)
        continuation.yield(.signedIn(session))
        return session
    }

    /// Replaces the session view after `GET`/`PATCH /auth/me`.
    func update(_ view: SessionViewDTO) throws {
        let session = try UserSession(view)
        sessionView = view
        persistSessionView()
        continuation.yield(.updated(session))
    }

    /// Forgets the session on this device (tokens and saved view).
    func signOutLocally(reason: SignOutReason) {
        refreshTask?.cancel()
        refreshTask = nil
        clearLocalState()
        continuation.yield(.signedOut(reason))
    }

    // MARK: Tokens

    /// A valid access token, refreshing first when less than a minute is left.
    /// Without network it returns the token it has, so the request fails as offline rather than signed out.
    func currentAccessToken() async -> String? {
        guard let tokens else { return nil }
        if let access = tokens.accessToken, let expiry = tokens.accessTokenExpiresAt,
           expiry.timeIntervalSince(now()) > Self.refreshMargin {
            return access
        }
        _ = await refresh()
        return self.tokens?.accessToken
    }

    /// Called by the API client after a 401. Returns whether the request should be retried.
    func handleUnauthorized() async -> Bool {
        await refresh() == .refreshed
    }

    /// Refreshes the tokens. Concurrent callers share the same request (single flight).
    func refresh() async -> RefreshOutcome {
        if let refreshTask {
            return await refreshTask.value
        }
        guard let refreshToken = tokens?.refreshToken else { return .expired }
        let task = Task { await self.performRefresh(refreshToken) }
        refreshTask = task
        let outcome = await task.value
        refreshTask = nil
        return outcome
    }

    // MARK: Private

    private func performRefresh(_ refreshToken: String) async -> RefreshOutcome {
        do {
            let request = try APIRequest(.post, "/auth/refresh", body: RefreshBody(refreshToken: refreshToken), requiresAuth: false)
            let result = try await client.send(request, as: AuthResultDTO.self)
            // The session may have ended while the request was in flight.
            guard tokens != nil else { return .expired }
            let previous = currentSession
            install(result)
            if let session = currentSession, session != previous {
                continuation.yield(.updated(session))
            }
            return .refreshed
        } catch let error as APIError where error.status == 401 {
            Self.logger.notice("El refresh token ya no sirve: se cierra la sesión.")
            signOutLocally(reason: .expired)
            return .expired
        } catch {
            Self.logger.notice("No se pudo renovar la sesión; se sigue sin conexión.")
            return .unavailable
        }
    }

    private func install(_ result: AuthResultDTO) {
        let stored = StoredTokens(
            refreshToken: result.refreshToken,
            refreshTokenExpiresAt: result.refreshTokenExpiresAt,
            accessToken: result.accessToken,
            accessTokenExpiresAt: result.accessTokenExpiresAt
        )
        tokens = stored
        tokenStore.save(stored)
        sessionView = result.sessionView
        persistSessionView()
    }

    private func persistSessionView() {
        guard let sessionFile, let sessionView, let data = try? JSONCoding.encoder.encode(sessionView) else { return }
        try? FileManager.default.createDirectory(at: sessionFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: sessionFile, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func clearLocalState() {
        tokens = nil
        sessionView = nil
        tokenStore.clear()
        if let sessionFile { try? FileManager.default.removeItem(at: sessionFile) }
    }
}
