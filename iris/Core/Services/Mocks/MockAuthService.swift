//
//  MockAuthService.swift
//  iris
//

import Foundation

/// In-memory auth with simulated latency.
///
/// Test hooks:
/// - Any email starting with `error@` fails sign-in.
/// - Any email starting with `existe@` fails sign-up as already registered.
/// - The recovery code `000000` is rejected.
struct MockAuthService: AuthService {
    var latency: Duration = .milliseconds(600)
    /// Session restored at launch, if any.
    var savedSession: UserSession?

    func restoreSession() async -> UserSession? { savedSession }

    func resumeSession() async {}

    func sessionEvents() -> AsyncStream<SessionEvent> {
        AsyncStream { _ in }
    }

    func signIn(_ credentials: SignInCredentials) async throws -> UserSession {
        try await Task.sleep(for: latency)
        if credentials.email.lowercased().hasPrefix("error@") {
            throw AuthError.api(code: "INVALID_CREDENTIALS", message: String(localized: "El correo o la contraseña no coinciden."), fieldErrors: [:])
        }
        var session = UserSession.preview
        session.email = credentials.email
        return session
    }

    func signUp(_ request: SignUpRequest) async throws -> UserSession {
        try await Task.sleep(for: latency)
        if request.email.lowercased().hasPrefix("existe@") {
            let message = String(localized: "Ya existe una cuenta con ese correo.")
            throw AuthError.api(code: "EMAIL_TAKEN", message: message, fieldErrors: ["email": message])
        }
        var session = UserSession.preview
        session.church.name = request.churchName
        session.churches = [UserSession.ChurchSummary(id: session.church.id, name: request.churchName, role: .owner)]
        session.fullName = request.fullName
        session.email = request.email
        return session
    }

    func signOut() async {}

    func signOutAll() async throws {
        try await Task.sleep(for: latency)
    }

    func switchChurch(to churchID: UUID) async throws -> UserSession {
        try await Task.sleep(for: latency)
        var session = savedSession ?? UserSession.preview
        if let church = session.churches.first(where: { $0.id == churchID }) {
            session.church = UserSession.Church(id: church.id, name: church.name, timeZone: session.church.timeZone)
            session.role = church.role
            session.permissions = Permission.granted(to: church.role)
        }
        return session
    }

    func reloadSession() async {}

    func requestPasswordReset(email: String) async throws {
        try await Task.sleep(for: latency)
    }

    func verifyResetCode(email: String, code: String) async throws {
        try await Task.sleep(for: latency)
        if code == "000000" {
            let message = String(localized: "El código no es correcto o ya venció.")
            throw AuthError.api(code: "RESET_CODE_INVALID", message: message, fieldErrors: ["code": message])
        }
    }

    func resetPassword(email: String, code: String, password: String, confirmation: String) async throws {
        try await Task.sleep(for: latency)
    }
}
