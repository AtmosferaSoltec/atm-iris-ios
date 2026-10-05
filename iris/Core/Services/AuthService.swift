//
//  AuthService.swift
//  iris
//

import Foundation

/// Authentication boundary. V1 ships with a mock; a network implementation
/// will conform to this same contract once the API exists.
protocol AuthService {
    func signIn(_ credentials: SignInCredentials) async throws -> UserSession
    func signUp(_ request: SignUpRequest) async throws -> UserSession
    func requestPasswordReset(email: String) async throws
}

nonisolated enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case emailAlreadyInUse
    case network

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            String(localized: "El correo o la contraseña no coinciden. Revísalos e inténtalo de nuevo.")
        case .emailAlreadyInUse:
            String(localized: "Ya existe una cuenta con ese correo. Intenta iniciar sesión.")
        case .network:
            String(localized: "No pudimos conectarnos. Verifica tu conexión a internet.")
        }
    }
}
