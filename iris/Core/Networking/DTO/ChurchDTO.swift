//
//  ChurchDTO.swift
//  iris
//
//  API contract §6, §8 and §9.
//

import Foundation

nonisolated struct ChurchModulesDTO: Codable, Hashable, Sendable {
    let bible: Bool
    let multimedia: Bool
    let timeControl: Bool
}

nonisolated struct ChurchDTO: Codable, Hashable, Sendable {
    nonisolated struct Storage: Codable, Hashable, Sendable {
        let usedBytes: Int64
        let quotaBytes: Int64
    }

    let id: String
    let name: String
    let timezone: String
    let modules: ChurchModulesDTO
    let storage: Storage
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct PersonDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let blockCount: Int
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct PersonCreateBody: Encodable, Sendable {
    let id: String
    let name: String
}

nonisolated struct PersonRenameBody: Encodable, Sendable {
    let name: String
}

nonisolated struct ScheduleDTO: Codable, Hashable, Sendable {
    let weekday: Int
    let hour: Int
    let minute: Int
}

nonisolated struct BlockTemplateDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let plannedMinutes: Int
    let defaultPersonId: String?

    // `defaultPersonId` travels as `null`, never omitted.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(plannedMinutes, forKey: .plannedMinutes)
        try container.encode(defaultPersonId, forKey: .defaultPersonId)
    }
}

nonisolated struct ServiceTypeDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let color: String
    let schedule: ScheduleDTO?
    let blocks: [BlockTemplateDTO]
    let createdAt: Date
    let updatedAt: Date
}

/// Body of `PUT /service-types/:id`. Blocks keep their ids, so a replace never loses them.
nonisolated struct ServiceTypeInputDTO: Encodable, Hashable, Sendable {
    let name: String
    let color: String
    let schedule: ScheduleDTO?
    let blocks: [BlockTemplateDTO]

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(blocks, forKey: .blocks)
    }

    private enum CodingKeys: String, CodingKey {
        case name, color, schedule, blocks
    }
}
