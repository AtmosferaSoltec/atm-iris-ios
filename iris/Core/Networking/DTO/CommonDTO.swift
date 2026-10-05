//
//  CommonDTO.swift
//  iris
//
//  Transport types shared by every endpoint (API contract §1).
//

import Foundation

/// `{ "data": … }`
nonisolated struct DataEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
}

nonisolated struct PageMetaDTO: Codable, Hashable, Sendable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

/// `{ "data": [ … ], "meta": { … } }`
nonisolated struct Paginated<T: Decodable & Sendable>: Decodable, Sendable {
    let data: [T]
    let meta: PageMetaDTO
}

/// Error body of every failed request.
nonisolated struct APIErrorBody: Codable, Hashable, Sendable {
    let statusCode: Int
    let code: String
    let message: String
    /// Per-field messages, keyed with dot notation ("blocks.2.name").
    let errors: [String: String]?
    let timestamp: Date?
    let path: String?
}

/// `{ message }` answers (forgot and reset password).
nonisolated struct MessageDTO: Codable, Hashable, Sendable {
    let message: String
}

nonisolated enum RoleDTO: String, TolerantStringEnum {
    case owner, admin, `operator`, unknown
}

nonisolated enum PlatformDTO: String, TolerantStringEnum {
    case web, ios, windows, unknown
}
