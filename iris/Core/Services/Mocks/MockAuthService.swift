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
struct MockAuthService: AuthService {
    var latency: Duration = .milliseconds(600)

    func signIn(_ credentials: SignInCredentials) async throws -> UserSession {
        try await Task.sleep(for: latency)
        if credentials.email.lowercased().hasPrefix("error@") {
            throw AuthError.invalidCredentials
        }
        return UserSession(
            id: UUID(),
            churchName: "Iglesia Vida Nueva",
            leaderName: "Daniel Ruiz",
            email: credentials.email.isEmpty ? "pastor@vidanueva.org" : credentials.email
        )
    }

    func signUp(_ request: SignUpRequest) async throws -> UserSession {
        try await Task.sleep(for: latency)
        if request.email.lowercased().hasPrefix("existe@") {
            throw AuthError.emailAlreadyInUse
        }
        return UserSession(
            id: UUID(),
            churchName: request.churchName,
            leaderName: request.leaderName,
            email: request.email
        )
    }

    func requestPasswordReset(email: String) async throws {
        try await Task.sleep(for: latency)
    }
}
