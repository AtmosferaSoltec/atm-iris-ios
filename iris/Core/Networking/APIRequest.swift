//
//  APIRequest.swift
//  iris
//

import Foundation

/// One call to the API, relative to its base URL.
nonisolated struct APIRequest: Sendable {
    nonisolated enum Method: String, Sendable, Codable {
        case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
    }

    var method: Method
    /// Path under the base URL, e.g. "/people/0199…".
    var path: String
    var query: [URLQueryItem] = []
    /// Already-encoded JSON body.
    var body: Data?
    /// `false` only for public endpoints (sign-in, refresh, password recovery).
    var requiresAuth = true
    /// Extra headers, e.g. `If-None-Match`.
    var headers: [String: String] = [:]

    init(_ method: Method, _ path: String, query: [URLQueryItem] = [], requiresAuth: Bool = true) {
        self.method = method
        self.path = path
        self.query = query
        self.requiresAuth = requiresAuth
    }

    init(_ method: Method, _ path: String, body: some Encodable, requiresAuth: Bool = true) throws {
        self.init(method, path, requiresAuth: requiresAuth)
        self.body = try JSONCoding.encoder.encode(body)
    }

    /// A stored request (from the outbox) with its raw body.
    init(method: Method, path: String, body: Data?) {
        self.method = method
        self.path = path
        self.body = body
    }
}
