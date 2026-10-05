//
//  APIClient.swift
//  iris
//

import Foundation
import os

/// HTTP client of the API contract. Only `Core/Networking`, `Core/Auth` and `Core/Sync` use it.
///
/// Token handling is injected: `tokenProvider` returns a fresh access token (refreshing first if
/// it is about to expire) and `onUnauthorized` refreshes once after a 401, returning whether to retry.
actor APIClient {
    typealias TokenProvider = @Sendable () async -> String?
    typealias UnauthorizedHandler = @Sendable () async -> Bool

    nonisolated let baseURL: URL?
    private let session: URLSession
    private let tokenProvider: TokenProvider
    private let onUnauthorized: UnauthorizedHandler

    private static let logger = Logger(subsystem: "com.atmosfera.iris", category: "network")

    init(
        baseURL: URL?,
        session: URLSession = .shared,
        tokenProvider: @escaping TokenProvider = { nil },
        onUnauthorized: @escaping UnauthorizedHandler = { false }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.onUnauthorized = onUnauthorized
    }

    /// Sends the request and unwraps `{ data }`.
    func send<T: Decodable & Sendable>(_ request: APIRequest, as type: T.Type = T.self) async throws -> T {
        let (data, _) = try await perform(request)
        return try decode(DataEnvelope<T>.self, from: data).data
    }

    /// Sends a paginated list request.
    func sendPage<T: Decodable & Sendable>(_ request: APIRequest, of type: T.Type = T.self) async throws -> Paginated<T> {
        let (data, _) = try await perform(request)
        return try decode(Paginated<T>.self, from: data)
    }

    /// Sends a request whose answer has no body we need (204, or a body that is ignored).
    func sendVoid(_ request: APIRequest) async throws {
        _ = try await perform(request)
    }

    /// Sends the request and returns the raw answer, for callers that read headers (ETag) or 304.
    /// With `progress`, the body is streamed and reported from 0 to 1 against `expectedBytes`
    /// (or the response's length when it is known).
    func sendRaw(
        _ request: APIRequest,
        expectedBytes: Int64? = nil,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let progress else { return try await perform(request, acceptsNotModified: true) }
        guard let baseURL else { throw APIError.notConfigured }
        var urlRequest = try makeURLRequest(request, baseURL: baseURL)
        if let token = await tokenProvider() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Request-Id")
        do {
            let (bytes, response) = try await session.bytes(for: urlRequest)
            guard let http = response as? HTTPURLResponse else { throw APIError.network(URLError(.badServerResponse)) }
            guard (200..<300).contains(http.statusCode) else {
                // Errors and 304 are small: read them through the normal path.
                return try await perform(request, acceptsNotModified: true)
            }
            let total = Double(expectedBytes ?? (http.expectedContentLength > 0 ? http.expectedContentLength : 0))
            var data = Data()
            if total > 0 { data.reserveCapacity(Int(total)) }
            var reported = 0.0
            for try await byte in bytes {
                data.append(byte)
                guard total > 0 else { continue }
                let fraction = min(0.99, Double(data.count) / total)
                if fraction - reported >= 0.01 {
                    reported = fraction
                    progress(fraction)
                }
            }
            Self.logger.info("\(request.method.rawValue, privacy: .public) \(request.path, privacy: .public) → \(http.statusCode) (\(data.count) bytes)")
            return (data, http)
        } catch let error as URLError {
            throw APIError.network(error)
        }
    }

    // MARK: Private

    private func perform(_ request: APIRequest, acceptsNotModified: Bool = false) async throws -> (Data, HTTPURLResponse) {
        var (data, response) = try await attempt(request)
        if response.statusCode == 401, request.requiresAuth {
            // Refresh once and retry; a second 401 means the session is gone.
            guard await onUnauthorized() else { throw APIError.unauthorized }
            (data, response) = try await attempt(request)
            if response.statusCode == 401 { throw APIError.unauthorized }
        }
        if (200..<300).contains(response.statusCode) || (acceptsNotModified && response.statusCode == 304) {
            return (data, response)
        }
        let body = (try? JSONCoding.decoder.decode(APIErrorBody.self, from: data))
            ?? APIErrorBody(statusCode: response.statusCode, code: "HTTP_\(response.statusCode)", message: "", errors: nil, timestamp: nil, path: request.path)
        throw APIError.http(status: response.statusCode, body: body)
    }

    private func attempt(_ request: APIRequest) async throws -> (Data, HTTPURLResponse) {
        guard let baseURL else { throw APIError.notConfigured }
        var urlRequest = try makeURLRequest(request, baseURL: baseURL)
        if request.requiresAuth, let token = await tokenProvider() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let requestID = UUID().uuidString.lowercased()
        urlRequest.setValue(requestID, forHTTPHeaderField: "X-Request-Id")

        let started = ContinuousClock.now
        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else { throw APIError.network(URLError(.badServerResponse)) }
            let elapsed = started.duration(to: .now)
            Self.logger.info("\(request.method.rawValue, privacy: .public) \(request.path, privacy: .public) → \(http.statusCode) en \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public) [\(requestID, privacy: .public)]")
            return (data, http)
        } catch let error as URLError {
            Self.logger.error("\(request.method.rawValue, privacy: .public) \(request.path, privacy: .public) sin respuesta: \(error.code.rawValue) [\(requestID, privacy: .public)]")
            throw APIError.network(error)
        }
    }

    private func makeURLRequest(_ request: APIRequest, baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: request.path), resolvingAgainstBaseURL: false)
        if !request.query.isEmpty { components?.queryItems = request.query }
        guard let url = components?.url else { throw APIError.network(URLError(.badURL)) }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = request.body {
            urlRequest.httpBody = body
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        return urlRequest
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONCoding.decoder.decode(type, from: data)
        } catch {
            Self.logger.error("Respuesta fuera del contrato: \(String(describing: error), privacy: .public)")
            throw APIError.decoding(error)
        }
    }
}
