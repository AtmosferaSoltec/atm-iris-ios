//
//  Church.swift
//  iris
//

import Foundation

/// Someone who can be responsible for a timed block.
nonisolated struct Person: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    /// "Daniel Ruiz" → "DR".
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// What the console offers. Iris no longer has modules (contract §6): every church has songs,
/// multimedia and time control, and the Bible is out for now — that is `.everything`. The type
/// stays until the console is rebuilt as a controller of the web screen; nothing can switch it.
nonisolated struct ChurchModules: Equatable, Sendable {
    var bible = false
    var multimedia = true
    var timeControl = true

    static let everything = ChurchModules()
}

/// A kind of service the church holds (Culto general, Jóvenes, ABC…).
nonisolated struct ServiceType: Identifiable, Hashable, Sendable {
    /// Usual day and time, used to suggest today's service.
    struct Schedule: Hashable, Sendable {
        /// 1 = Sunday … 7 = Saturday (Calendar convention).
        var weekday: Int
        var hour: Int
        var minute: Int
    }

    let id: UUID
    var name: String
    /// 24-bit hex accent color.
    var color: UInt32
    var schedule: Schedule?
    /// Empty when the service does not track time.
    var blocks: [BlockTemplate]

    init(id: UUID = UUID(), name: String, color: UInt32, schedule: Schedule?, blocks: [BlockTemplate] = []) {
        self.id = id
        self.name = name
        self.color = color
        self.schedule = schedule
        self.blocks = blocks
    }

    var tracksTime: Bool { !blocks.isEmpty }

    /// Colors a service can take: the spectrum tokens plus success, as hex.
    static let palette: [UInt32] = [0xFFB547, 0xFF7A59, 0xF0508C, 0x9B5CFF, 0x4E5BFF, 0x3DDC97]

    var plannedSeconds: TimeInterval {
        blocks.reduce(0) { $0 + $1.plannedSeconds }
    }
}

/// A timed section of a service template.
nonisolated struct BlockTemplate: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var plannedMinutes: Int
    var defaultPersonID: Person.ID?

    init(id: UUID = UUID(), name: String, plannedMinutes: Int, defaultPersonID: Person.ID? = nil) {
        self.id = id
        self.name = name
        self.plannedMinutes = plannedMinutes
        self.defaultPersonID = defaultPersonID
    }

    var plannedSeconds: TimeInterval { TimeInterval(plannedMinutes * 60) }
}

/// The saved timing of one service. Only times are stored, never the content used.
nonisolated struct ServiceRecord: Identifiable, Hashable, Sendable {
    /// The console saves the record from the first block on and sends it again on every change, so a service
    /// survives the app closing: it stays `inProgress` until "Terminar" (contract §14).
    enum Status: Hashable, Sendable {
        case inProgress, finished
    }

    let id: UUID
    var status: Status
    var date: Date
    var serviceTypeID: ServiceType.ID
    /// Name of the service type when the record was saved, shown if the type is deleted.
    var serviceTypeName: String?
    var blocks: [BlockRecord]

    init(
        id: UUID = UUID(),
        status: Status = .finished,
        date: Date,
        serviceTypeID: ServiceType.ID,
        serviceTypeName: String? = nil,
        blocks: [BlockRecord]
    ) {
        self.id = id
        self.status = status
        self.date = date
        self.serviceTypeID = serviceTypeID
        self.serviceTypeName = serviceTypeName
        self.blocks = blocks
    }

    var isInProgress: Bool { status == .inProgress }

    private var countedBlocks: [BlockRecord] { blocks.filter(\.hasTime) }

    var plannedSeconds: TimeInterval { countedBlocks.reduce(0) { $0 + $1.plannedSeconds } }
    var actualSeconds: TimeInterval { countedBlocks.reduce(0) { $0 + $1.actualSeconds } }
    var overtimeSeconds: TimeInterval { max(0, actualSeconds - plannedSeconds) }
}

nonisolated struct BlockRecord: Identifiable, Hashable, Sendable {
    enum Status: Hashable, Sendable {
        /// Only in a service in progress: not reached yet, and the block that runs now.
        case pending, running
        case completed, skipped, adjusted
    }

    let id: UUID
    var name: String
    var plannedSeconds: TimeInterval
    var actualSeconds: TimeInterval
    var personID: Person.ID?
    /// Name of the person when the record was saved, so it stays readable after a rename or delete.
    var personName: String?
    var status: Status
    /// The console's clock, kept so a running block can be resumed where it was.
    var startedAt: Date?
    var endedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        plannedSeconds: TimeInterval,
        actualSeconds: TimeInterval,
        personID: Person.ID?,
        personName: String? = nil,
        status: Status = .completed,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.personID = personID
        self.personName = personName
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// Skipped and pending blocks have no time of their own and don't count in totals.
    var hasTime: Bool { status != .skipped && status != .pending }

    /// Any second over planned counts — there is no tolerance margin.
    var overtimeSeconds: TimeInterval { max(0, actualSeconds - plannedSeconds) }
    var isOver: Bool { hasTime && actualSeconds > plannedSeconds }

    /// The person's current name if they still exist, else the name saved with the record.
    func resolvedPersonName(in people: [Person]) -> String? {
        people.first { $0.id == personID }?.name ?? personName
    }
}
