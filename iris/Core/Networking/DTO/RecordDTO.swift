//
//  RecordDTO.swift
//  iris
//
//  API contract §12 and §14.
//

import Foundation

nonisolated enum BlockStatusDTO: String, TolerantStringEnum {
    case completed, skipped, adjusted, unknown
}

nonisolated struct BlockRecordDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let plannedSeconds: Int
    let actualSeconds: Int
    let personId: String?
    let personName: String?
    let status: BlockStatusDTO

    // Optional fields travel as `null`, never omitted.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(plannedSeconds, forKey: .plannedSeconds)
        try container.encode(actualSeconds, forKey: .actualSeconds)
        try container.encode(personId, forKey: .personId)
        try container.encode(personName, forKey: .personName)
        try container.encode(status, forKey: .status)
    }
}

nonisolated struct ServiceRecordDTO: Codable, Hashable, Sendable {
    let id: String
    let date: Date
    let serviceTypeId: String
    let serviceTypeName: String
    let blocks: [BlockRecordDTO]
    let createdAt: Date
    let updatedAt: Date
}

/// Body of `PUT /service-records/:id`. Block status is `completed` or `skipped` when created.
nonisolated struct ServiceRecordInputDTO: Encodable, Hashable, Sendable {
    let date: Date
    let serviceTypeId: String
    let serviceTypeName: String
    let blocks: [BlockRecordDTO]
}

/// Body of `PATCH /service-records/:id/blocks/:blockId`: only the fields being changed.
nonisolated struct BlockRecordPatchBody: Encodable, Sendable {
    nonisolated enum Change: Sendable {
        case actualSeconds(Int)
        case person(String?)
    }

    let change: Change

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch change {
        case let .actualSeconds(seconds): try container.encode(seconds, forKey: .actualSeconds)
        case let .person(id): try container.encode(id, forKey: .personId)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case actualSeconds, personId
    }
}

/// One page of `GET /sync/changes`.
nonisolated struct SyncPageDTO: Codable, Hashable, Sendable {
    nonisolated struct Changes: Codable, Hashable, Sendable {
        let people: [PersonDTO]
        let serviceTypes: [ServiceTypeDTO]
        let songs: [SongDTO]
        let media: [MediaAssetDTO]
        let serviceRecords: [ServiceRecordDTO]
        let servicePlan: [ServicePlanItemDTO]
    }

    nonisolated struct Deleted: Codable, Hashable, Sendable {
        let people: [String]
        let serviceTypes: [String]
        let songs: [String]
        let media: [String]
        let serviceRecords: [String]
        let servicePlan: [String]
    }

    let church: ChurchDTO?
    let changes: Changes
    let deleted: Deleted
    let cursor: String
    let hasMore: Bool
}
