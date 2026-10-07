//
//  StubServer.swift
//  irisTests
//

import Foundation
import Synchronization
@testable import iris

/// A fake API behind `URLProtocol`. Each server has its own host, so tests can run in parallel.
nonisolated final class StubServer: Sendable {
    nonisolated struct Request: Sendable {
        let method: String
        let path: String
        let query: [String: String]
        let headers: [String: String]
        let body: Data?

        func json<T: Decodable>(_ type: T.Type) throws -> T {
            try JSONCoding.decoder.decode(type, from: body ?? Data())
        }
    }

    nonisolated struct Response: Sendable {
        var status: Int
        var body: Data
        var headers: [String: String] = [:]

        static func data(_ json: String, status: Int = 200) -> Response {
            Response(status: status, body: Data("{\"data\":\(json)}".utf8))
        }

        static func error(_ status: Int, code: String, message: String = "Error de prueba.") -> Response {
            Response(status: status, body: Data("""
            {"statusCode":\(status),"code":"\(code)","message":"\(message)","timestamp":"2026-10-05T15:30:31.022Z","path":"/x"}
            """.utf8))
        }

        static let noContent = Response(status: 204, body: Data())
        /// Makes the client see a dropped connection.
        static let offline = Response(status: -1, body: Data())
    }

    typealias Handler = @Sendable (Request) -> Response

    let host = "stub-\(UUID().uuidString.lowercased())"
    private let handler: Mutex<Handler>
    private let log = Mutex<[Request]>([])

    init(_ handler: @escaping Handler) {
        self.handler = Mutex(handler)
        StubURLProtocol.servers.withLock { $0[host] = self }
    }

    var baseURL: URL { URL(string: "http://\(host)/api/v1")! }

    var requests: [Request] { log.withLock { $0 } }

    func setHandler(_ handler: @escaping Handler) {
        self.handler.withLock { $0 = handler }
    }

    func client(
        tokenProvider: @escaping APIClient.TokenProvider = { nil },
        onUnauthorized: @escaping APIClient.UnauthorizedHandler = { false }
    ) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(baseURL: baseURL, session: URLSession(configuration: configuration), tokenProvider: tokenProvider, onUnauthorized: onUnauthorized)
    }

    fileprivate func respond(to urlRequest: URLRequest) -> Response {
        let url = urlRequest.url!
        var body = urlRequest.httpBody
        if body == nil, let stream = urlRequest.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            stream.close()
            body = data
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = Dictionary((components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })
        let request = Request(
            method: urlRequest.httpMethod ?? "GET",
            path: String(url.path.dropFirst("/api/v1".count)),
            query: query,
            headers: urlRequest.allHTTPHeaderFields ?? [:],
            body: body
        )
        log.withLock { $0.append(request) }
        return handler.withLock { $0 }(request)
    }
}

nonisolated final class StubURLProtocol: URLProtocol {
    static let servers = Mutex<[String: StubServer]>([:])

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let host = request.url?.host, let server = Self.servers.withLock({ $0[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let response = server.respond(to: request)
        guard response.status > 0 else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: response.headers)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// JSON samples of the contract.
nonisolated enum ContractSamples {
    static let churchID = "01a20cb0-1d73-709f-b03e-c6c9c36a17f0"

    static func authResult(accessExpiresAt: String = "2026-10-05T15:45:31.022Z", role: String = "owner", token: String = "access-1", refresh: String = "refresh-1") -> String {
        """
        {"user":{"id":"01a10cb0-1d73-709f-b03e-c6c9c36a17f0","email":"pastor@vidanueva.org","fullName":"Daniel Ruiz"},
        "church":{"id":"\(churchID)","name":"Iglesia Vida Nueva","timezone":"America/Lima"},
        "role":"\(role)","permissions":["church.manage","modules.manage","members.manage","songs.manage","media.manage","serviceTypes.manage","people.manage","records.write","records.manage"],
        "churches":[{"id":"\(churchID)","name":"Iglesia Vida Nueva","role":"\(role)"}],
        "session":{"id":"01a30cb0-1d73-709f-b03e-c6c9c36a17f0","platform":"ios","deviceName":"iPad de la sala"},
        "accessToken":"\(token)","accessTokenExpiresAt":"\(accessExpiresAt)",
        "refreshToken":"\(refresh)","refreshTokenExpiresAt":"2026-12-04T15:30:31.022Z"}
        """
    }

    static func person(_ id: String, _ name: String) -> String {
        #"{"id":"\#(id)","name":"\#(name)","blockCount":0,"createdAt":"2026-10-01T10:00:00.000Z","updatedAt":"2026-10-01T10:00:00.000Z"}"#
    }

    static func serviceType(_ id: String, _ name: String, defaultPersonID: String? = nil) -> String {
        let person = defaultPersonID.map { "\"\($0)\"" } ?? "null"
        return """
        {"id":"\(id)","name":"\(name)","color":"#FFB547","schedule":{"weekday":1,"hour":10,"minute":0},
        "blocks":[{"id":"0199aaaa-0000-7000-8000-000000000001","name":"Prédica","plannedMinutes":40,"defaultPersonId":\(person)}],
        "createdAt":"2026-10-01T10:00:00.000Z","updatedAt":"2026-10-01T10:00:00.000Z"}
        """
    }

    static let serviceRecord = """
    {"id":"0199bbbb-0000-7000-8000-000000000001","date":"2026-10-04T15:00:00.000Z","serviceTypeId":"0199cccc-0000-7000-8000-000000000001",
    "serviceTypeName":"Culto general","blocks":[
    {"id":"0199bbbb-0000-7000-8000-000000000002","name":"Prédica","plannedSeconds":2400,"actualSeconds":2700,"personId":null,"personName":"Daniel Ruiz","status":"adjusted"},
    {"id":"0199bbbb-0000-7000-8000-000000000003","name":"Anuncios","plannedSeconds":300,"actualSeconds":0,"personId":null,"personName":null,"status":"skipped"}],
    "createdAt":"2026-10-04T17:00:00.000Z","updatedAt":"2026-10-04T17:00:00.000Z"}
    """

    static let church = """
    {"id":"\(churchID)","name":"Iglesia Vida Nueva","timezone":"America/Lima","modules":{"bible":true,"multimedia":false,"timeControl":true},
    "storage":{"usedBytes":0,"quotaBytes":5368709120},"createdAt":"2026-10-01T10:00:00.000Z","updatedAt":"2026-10-01T10:00:00.000Z"}
    """

    static func syncPage(church: String? = nil, people: [String] = [], serviceTypes: [String] = [], deletedPeople: [String] = [], cursor: String, hasMore: Bool) -> String {
        """
        {"church":\(church ?? "null"),
        "changes":{"people":[\(people.joined(separator: ","))],"serviceTypes":[\(serviceTypes.joined(separator: ","))],"songs":[],"media":[],"serviceRecords":[],"servicePlan":[]},
        "deleted":{"people":[\(deletedPeople.map { "\"\($0)\"" }.joined(separator: ","))],"serviceTypes":[],"songs":[],"media":[],"serviceRecords":[],"servicePlan":[]},
        "cursor":"\(cursor)","hasMore":\(hasMore)}
        """
    }
}
