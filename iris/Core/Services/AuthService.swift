//
//  AuthService.swift
//  iris
//

import Foundation

/// Authentication boundary (API contract §4–§5). `LiveAuthService` talks to the API;
/// `MockAuthService` keeps previews and `-IrisDataMode mock` working.
protocol AuthService {
    /// Session saved on this device, without touching the network. `nil` shows the sign-in screen.
    func restoreSession() async -> UserSession?
    /// Renews the restored session in the background. Expiry arrives through `sessionEvents()`.
    func resumeSession() async
    /// Sign-in, refresh, switch-church and sign-out changes. One consumer: `SessionStore`.
    func sessionEvents() -> AsyncStream<SessionEvent>

    func signIn(_ credentials: SignInCredentials) async throws -> UserSession
    func signUp(_ request: SignUpRequest) async throws -> UserSession
    /// Signs out on the API when possible; always forgets the session locally.
    func signOut() async
    /// Closes every session of the account (web, iPad, Windows), this one included.
    func signOutAll() async throws
    /// Enters another church of the account with the same session.
    func switchChurch(to churchID: UUID) async throws -> UserSession
    /// Reloads name, role and permissions (`GET /auth/me`). Silent when offline.
    func reloadSession() async

    func requestPasswordReset(email: String) async throws
    func verifyResetCode(email: String, code: String) async throws
    func resetPassword(email: String, code: String, password: String, confirmation: String) async throws
}

nonisolated enum AuthError: LocalizedError, Equatable {
    /// The API refused the request; `message` is its Spanish text, `fieldErrors` its per-field messages.
    case api(code: String, message: String, fieldErrors: [String: String])
    case network

    init(_ error: any Error) {
        switch error {
        case let error as AuthError:
            self = error
        case let error as APIError:
            switch error {
            case .network: self = .network
            case .http: self = .api(code: error.code ?? "", message: error.message, fieldErrors: error.fieldErrors)
            default: self = .api(code: "", message: error.message, fieldErrors: [:])
            }
        default:
            self = .api(code: "", message: String(localized: "Algo salió mal. Inténtalo de nuevo."), fieldErrors: [:])
        }
    }

    var code: String? {
        if case let .api(code, _, _) = self { return code }
        return nil
    }

    var fieldErrors: [String: String] {
        if case let .api(_, _, fieldErrors) = self { return fieldErrors }
        return [:]
    }

    var errorDescription: String? {
        switch self {
        case let .api(_, message, _): message
        case .network: String(localized: "No pudimos conectarnos. Verifica tu conexión a internet.")
        }
    }
}
