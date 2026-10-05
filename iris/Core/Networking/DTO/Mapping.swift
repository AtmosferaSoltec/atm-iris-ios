//
//  Mapping.swift
//  iris
//
//  Transport types ⇄ app models. The app never shows DTOs directly.
//

import Foundation

/// A DTO that cannot become an app model (an id that is not a UUID, for example).
nonisolated struct MappingError: Error, Sendable {
    let detail: String
}

nonisolated extension UUID {
    init(apiID: String) throws {
        guard let uuid = UUID(uuidString: apiID) else { throw MappingError(detail: "Id no válido: \(apiID)") }
        self = uuid
    }
}

// MARK: Session

nonisolated extension UserSession.Role {
    init(_ dto: RoleDTO) {
        switch dto {
        case .owner: self = .owner
        case .admin: self = .admin
        // An unknown role gets the narrowest view; permissions decide anyway.
        case .operator, .unknown: self = .operator
        }
    }
}

nonisolated extension UserSession.Platform {
    init(_ dto: PlatformDTO) {
        switch dto {
        case .web: self = .web
        case .windows: self = .windows
        case .ios, .unknown: self = .ios
        }
    }
}

nonisolated extension UserSession {
    init(_ dto: SessionViewDTO) throws {
        self.init(
            userID: try UUID(apiID: dto.user.id),
            email: dto.user.email,
            fullName: dto.user.fullName,
            church: Church(
                id: try UUID(apiID: dto.church.id),
                name: dto.church.name,
                timeZone: TimeZone(identifier: dto.church.timezone) ?? TimeZone(identifier: "America/Lima") ?? .current
            ),
            role: Role(dto.role),
            permissions: Set(dto.permissions.compactMap(Permission.init(rawValue:))),
            churches: try dto.churches.map {
                ChurchSummary(id: try UUID(apiID: $0.id), name: $0.name, role: Role($0.role))
            },
            sessionID: try UUID(apiID: dto.session.id),
            platform: Platform(dto.session.platform)
        )
    }
}

// MARK: Church

nonisolated extension ChurchModules {
    init(_ dto: ChurchModulesDTO) {
        self.init(bible: dto.bible, multimedia: dto.multimedia, timeControl: dto.timeControl)
    }

    var dto: ChurchModulesDTO {
        ChurchModulesDTO(bible: bible, multimedia: multimedia, timeControl: timeControl)
    }
}

nonisolated extension Person {
    init(_ dto: PersonDTO) throws {
        self.init(id: try UUID(apiID: dto.id), name: dto.name)
    }
}

nonisolated enum HexColor {
    /// "#FFB547" → 0xFFB547.
    static func value(_ text: String) -> UInt32? {
        UInt32(text.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16)
    }

    /// 0xFFB547 → "#FFB547".
    static func text(_ value: UInt32) -> String {
        "#" + String(format: "%06X", value & 0xFFFFFF)
    }
}

nonisolated extension ServiceType {
    init(_ dto: ServiceTypeDTO) throws {
        self.init(
            id: try UUID(apiID: dto.id),
            name: dto.name,
            color: HexColor.value(dto.color) ?? ServiceType.palette[0],
            schedule: dto.schedule.map { Schedule(weekday: $0.weekday, hour: $0.hour, minute: $0.minute) },
            blocks: try dto.blocks.map { block in
                BlockTemplate(
                    id: try UUID(apiID: block.id),
                    name: block.name,
                    plannedMinutes: block.plannedMinutes,
                    defaultPersonID: try block.defaultPersonId.map(UUID.init(apiID:))
                )
            }
        )
    }

    var inputDTO: ServiceTypeInputDTO {
        ServiceTypeInputDTO(
            name: name,
            color: HexColor.text(color),
            schedule: schedule.map { ScheduleDTO(weekday: $0.weekday, hour: $0.hour, minute: $0.minute) },
            blocks: blocks.map {
                BlockTemplateDTO(id: $0.id.apiString, name: $0.name, plannedMinutes: $0.plannedMinutes, defaultPersonId: $0.defaultPersonID?.apiString)
            }
        )
    }
}

// MARK: Records

nonisolated extension BlockRecord.Status {
    init(_ dto: BlockStatusDTO) {
        switch dto {
        case .skipped: self = .skipped
        case .adjusted: self = .adjusted
        case .completed, .unknown: self = .completed
        }
    }

    var dto: BlockStatusDTO {
        switch self {
        case .completed: .completed
        case .skipped: .skipped
        case .adjusted: .adjusted
        }
    }
}

nonisolated extension ServiceRecord {
    init(_ dto: ServiceRecordDTO) throws {
        self.init(
            id: try UUID(apiID: dto.id),
            date: dto.date,
            serviceTypeID: try UUID(apiID: dto.serviceTypeId),
            serviceTypeName: dto.serviceTypeName,
            blocks: try dto.blocks.map { block in
                BlockRecord(
                    id: try UUID(apiID: block.id),
                    name: block.name,
                    plannedSeconds: TimeInterval(block.plannedSeconds),
                    actualSeconds: TimeInterval(block.actualSeconds),
                    personID: try block.personId.map(UUID.init(apiID:)),
                    personName: block.personName,
                    status: BlockRecord.Status(block.status)
                )
            }
        )
    }

    /// Body of `PUT /service-records/:id`. A new record only has completed or skipped blocks.
    var inputDTO: ServiceRecordInputDTO {
        ServiceRecordInputDTO(
            date: date,
            serviceTypeId: serviceTypeID.apiString,
            serviceTypeName: serviceTypeName ?? "",
            blocks: blocks.map(\.dto)
        )
    }

    /// Full transport form, used to keep the local copy.
    func dto(createdAt: Date, updatedAt: Date) -> ServiceRecordDTO {
        ServiceRecordDTO(
            id: id.apiString,
            date: date,
            serviceTypeId: serviceTypeID.apiString,
            serviceTypeName: serviceTypeName ?? "",
            blocks: blocks.map(\.dto),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

nonisolated extension BlockRecord {
    var dto: BlockRecordDTO {
        BlockRecordDTO(
            id: id.apiString,
            name: name,
            plannedSeconds: Int(plannedSeconds.rounded()),
            actualSeconds: status == .skipped ? 0 : Int(actualSeconds.rounded()),
            personId: personID?.apiString,
            personName: personName,
            status: status.dto
        )
    }
}

// MARK: Library

nonisolated extension LyricSheet {
    init(_ dto: SongDTO) throws {
        self.init(
            id: try UUID(apiID: dto.id),
            title: dto.title,
            author: dto.author,
            copyright: dto.copyright,
            sections: try dto.sections.map { section in
                Slide(id: try UUID(apiID: section.id), label: section.label, content: .text(section.text, footnote: nil))
            }
        )
    }
}

nonisolated extension BibleBook.Testament {
    init(_ dto: TestamentDTO) {
        self = dto == .new ? .new : .old
    }
}
