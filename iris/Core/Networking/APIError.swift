//
//  APIError.swift
//  iris
//

import Foundation

/// A failed API call. `message` is always Spanish and can be shown as is.
nonisolated enum APIError: Error, LocalizedError {
    /// The API answered with an error body (contract §1.2).
    case http(status: Int, body: APIErrorBody)
    /// No connection, timeout or the server could not be reached.
    case network(URLError)
    /// The answer did not match the contract.
    case decoding(any Error)
    /// The session is gone: the refresh token no longer works.
    case unauthorized
    /// This build has no API address.
    case notConfigured

    var message: String {
        switch self {
        case let .http(status, body):
            if status >= 500 { return Self.genericMessage }
            return body.message.isEmpty ? Self.genericMessage : body.message
        case .network:
            return String(localized: "No pudimos conectarnos. Verifica tu conexión a internet.")
        case .decoding:
            return Self.genericMessage
        case .unauthorized:
            return String(localized: "Tu sesión expiró. Vuelve a iniciar sesión.")
        case .notConfigured:
            return String(localized: "Esta versión de Iris no tiene un servidor configurado.")
        }
    }

    var errorDescription: String? { message }

    /// Stable error code of the API, when there is one.
    var code: String? {
        if case let .http(_, body) = self { return body.code }
        return nil
    }

    var status: Int? {
        if case let .http(status, _) = self { return status }
        return nil
    }

    var fieldErrors: [String: String] {
        if case let .http(_, body) = self { return body.errors ?? [:] }
        return [:]
    }

    /// Worth retrying later: no connection, server errors and rate limits.
    var isTransient: Bool {
        switch self {
        case .network: true
        case let .http(status, _): status >= 500 || status == 429
        case .decoding, .unauthorized, .notConfigured: false
        }
    }

    private static var genericMessage: String {
        String(localized: "Algo salió mal. Inténtalo de nuevo.")
    }
}
