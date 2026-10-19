//
//  BlockTimer.swift
//  iris
//

import Foundation

/// Pure state machine for timing a service's blocks. Time is injected for testability.
nonisolated struct BlockTimer: Equatable, Sendable {
    struct Block: Identifiable, Equatable, Sendable {
        /// Same id as the template block it comes from; a new one for blocks added today.
        let id: UUID
        var name: String
        var plannedSeconds: TimeInterval
        var personID: Person.ID?
        var startedAt: Date?
        var endedAt: Date?
        var isSkipped: Bool
        /// Added during the service.
        var isAddedToday: Bool

        var plannedMinutes: Int { Int((plannedSeconds / 60).rounded()) }
    }

    enum Phase: Equatable, Sendable {
        case notStarted, running, finished
    }

    /// How a block's clock looks. There is no tolerance margin: one second over is over.
    enum ClockState: Equatable, Sendable {
        case normal, warning, over

        init(elapsed: TimeInterval, planned: TimeInterval) {
            let seconds = elapsed.rounded(.down)
            if seconds > planned {
                self = .over
            } else if planned > 0, seconds / planned >= 0.9 {
                self = .warning
            } else {
                self = .normal
            }
        }
    }

    /// What today's blocks changed against the template.
    struct TemplateChanges: Equatable, Sendable {
        var added: [String] = []
        var skipped: [String] = []
        var edited: [String] = []
        var isReordered = false

        var isEmpty: Bool { added.isEmpty && skipped.isEmpty && edited.isEmpty && !isReordered }
    }

    private(set) var blocks: [Block]
    private(set) var phase: Phase = .notStarted
    private(set) var currentIndex: Int?
    private let template: [BlockTemplate]

    init(template: [BlockTemplate]) {
        self.template = template
        blocks = template.map {
            Block(
                id: $0.id,
                name: $0.name,
                plannedSeconds: $0.plannedSeconds,
                personID: $0.defaultPersonID,
                startedAt: nil,
                endedAt: nil,
                isSkipped: false,
                isAddedToday: false
            )
        }
    }

    /// Picks up a service saved while it ran (see `record`): same blocks, leaders and clock, so the current block
    /// keeps counting from when it really started. `nil` when the record has no running block to continue.
    init?(resuming record: ServiceRecord, template: [BlockTemplate]) {
        guard record.isInProgress,
              let current = record.blocks.firstIndex(where: { $0.status == .running }),
              record.blocks[current].startedAt != nil else { return nil }
        self.template = template
        blocks = record.blocks.map { block in
            let templateID = template.first { Self.recordBlockID(of: $0.id, in: record.id) == block.id }?.id
            return Block(
                id: templateID ?? Self.recordBlockID(of: block.id, in: record.id),
                name: block.name,
                plannedSeconds: block.plannedSeconds,
                personID: block.personID,
                startedAt: block.startedAt,
                endedAt: block.status == .running ? nil : block.endedAt,
                isSkipped: block.status == .skipped,
                isAddedToday: templateID == nil
            )
        }
        currentIndex = current
        phase = .running
    }

    // MARK: Reading

    var currentBlock: Block? { currentIndex.map { blocks[$0] } }

    /// Blocks not reached yet (all of them before starting). Only these can be edited, skipped or moved.
    var pendingBlocks: [Block] { Array(blocks[pendingRange]) }

    /// The block that runs next: the first pending one that is not skipped.
    var nextBlock: Block? { nextRunnableIndex.map { blocks[$0] } }

    func elapsed(of id: Block.ID, now: Date) -> TimeInterval {
        guard let block = block(id), let start = block.startedAt else { return 0 }
        return max(0, (block.endedAt ?? now).timeIntervalSince(start))
    }

    func clockState(of id: Block.ID, now: Date) -> ClockState {
        ClockState(elapsed: elapsed(of: id, now: now), planned: block(id)?.plannedSeconds ?? 0)
    }

    /// Added, skipped, edited (name or minutes) or reordered blocks. Choosing a different leader is not a change.
    var templateChanges: TemplateChanges {
        var changes = TemplateChanges()
        let originals = Dictionary(template.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for block in blocks {
            if block.isAddedToday {
                if !block.isSkipped { changes.added.append(block.name) }
            } else if block.isSkipped {
                changes.skipped.append(block.name)
            } else if let original = originals[block.id],
                      original.name != block.name || original.plannedMinutes != block.plannedMinutes {
                changes.edited.append(original.name)
            }
        }
        let kept = blocks.filter { !$0.isAddedToday && !$0.isSkipped }.map(\.id)
        changes.isReordered = kept != template.map(\.id).filter { kept.contains($0) }
        return changes
    }

    var hasTemplateChanges: Bool { !templateChanges.isEmpty }

    // MARK: Running

    /// Starts the first block that is not skipped.
    mutating func start(personID: Person.ID?, at date: Date) {
        guard phase == .notStarted, let index = nextRunnableIndex else { return }
        begin(index, personID: personID, at: date)
    }

    /// Closes the current block and opens the next one; finishes when there is none.
    mutating func advance(nextPersonID: Person.ID?, at date: Date) {
        guard phase == .running, let current = currentIndex else { return }
        blocks[current].endedAt = date
        if let next = nextRunnableIndex {
            begin(next, personID: nextPersonID, at: date)
        } else {
            phase = .finished
            currentIndex = nil
        }
    }

    /// Closes the current block and ends the service. Blocks not reached are recorded as skipped.
    mutating func finish(at date: Date) {
        guard phase == .running else { return }
        if let current = currentIndex { blocks[current].endedAt = date }
        phase = .finished
        currentIndex = nil
    }

    // MARK: Changing today's blocks (never the template)

    /// Inserts right after the current block, or at the end before starting.
    mutating func addBlock(name: String, plannedMinutes: Int, personID: Person.ID?) {
        guard phase != .finished else { return }
        let block = Block(
            id: UUID(),
            name: name,
            plannedSeconds: TimeInterval(max(1, plannedMinutes) * 60),
            personID: personID,
            startedAt: nil,
            endedAt: nil,
            isSkipped: false,
            isAddedToday: true
        )
        blocks.insert(block, at: currentIndex.map { $0 + 1 } ?? blocks.count)
    }

    mutating func skip(_ id: Block.ID) {
        guard let index = pendingIndex(of: id) else { return }
        blocks[index].isSkipped = true
    }

    mutating func restore(_ id: Block.ID) {
        guard let index = pendingIndex(of: id) else { return }
        blocks[index].isSkipped = false
    }

    /// `personID: .some(nil)` clears the leader; `nil` leaves it as is.
    mutating func updatePending(_ id: Block.ID, name: String?, plannedMinutes: Int?, personID: Person.ID??) {
        guard let index = pendingIndex(of: id) else { return }
        if let name { blocks[index].name = name }
        if let plannedMinutes { blocks[index].plannedSeconds = TimeInterval(max(1, plannedMinutes) * 60) }
        if let personID { blocks[index].personID = personID }
    }

    /// Offsets are positions within `pendingBlocks`, with `Array.move(fromOffsets:toOffset:)` semantics.
    mutating func movePending(from source: IndexSet, to destination: Int) {
        var pending = pendingBlocks
        guard source.allSatisfy(pending.indices.contains) else { return }
        let moving = source.sorted().map { pending[$0] }
        pending = pending.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = min(pending.count, max(0, destination - source.filter { $0 < destination }.count))
        pending.insert(contentsOf: moving, at: insertAt)
        blocks.replaceSubrange(pendingRange, with: pending)
    }

    /// Also allowed on finished blocks, to correct who led them.
    mutating func setPerson(_ id: Block.ID, personID: Person.ID?) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].personID = personID
    }

    // MARK: Results

    /// While running, the record is `inProgress` and says where the service is, so it can be resumed: the current
    /// block is `running` (timed up to `now`) and the blocks still to come keep their leader as `pending` or
    /// `skipped`. Once finished, skipped and never-reached blocks are saved with status `.skipped`, no time and
    /// no leader. `serviceTypeName` is kept with the record so it stays readable if the type is deleted.
    func record(
        id: ServiceRecord.ID = UUID(),
        serviceTypeID: ServiceType.ID,
        serviceTypeName: String? = nil,
        date: Date,
        peopleNames: [Person.ID: String],
        now: Date? = nil
    ) -> ServiceRecord {
        let isRunning = phase == .running
        let records = blocks.indices.map { index in
            let block = blocks[index]
            let status: BlockRecord.Status = if block.isSkipped {
                .skipped
            } else if index == currentIndex {
                .running
            } else if block.startedAt != nil {
                .completed
            } else {
                isRunning ? .pending : .skipped
            }
            let ran = status == .completed || status == .running
            let personID = ran || isRunning ? block.personID : nil
            return BlockRecord(
                id: Self.recordBlockID(of: block.id, in: id),
                name: block.name,
                plannedSeconds: block.plannedSeconds,
                actualSeconds: ran ? elapsed(of: block.id, now: block.endedAt ?? now ?? date).rounded(.down) : 0,
                personID: personID,
                personName: personID.flatMap { peopleNames[$0] },
                status: status,
                startedAt: ran ? block.startedAt : nil,
                endedAt: status == .completed ? block.endedAt : nil
            )
        }
        return ServiceRecord(
            id: id,
            status: isRunning ? .inProgress : .finished,
            date: date,
            serviceTypeID: serviceTypeID,
            serviceTypeName: serviceTypeName,
            blocks: records
        )
    }

    /// Today's order, names and minutes, without the skipped blocks. Template leaders are kept;
    /// blocks added today take today's leader as suggestion.
    func updatedTemplate(_ original: [BlockTemplate]) -> [BlockTemplate] {
        let originals = Dictionary(original.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return blocks.filter { !$0.isSkipped }.map { block in
            if var template = originals[block.id] {
                template.name = block.name
                template.plannedMinutes = block.plannedMinutes
                return template
            }
            return BlockTemplate(id: block.id, name: block.name, plannedMinutes: block.plannedMinutes, defaultPersonID: block.personID)
        }
    }

    /// A block's id in the saved record. The template's ids repeat every service, so it mixes in the record's:
    /// unique per record, the same on every save of one service, and applying it twice gives the block back.
    static func recordBlockID(of blockID: Block.ID, in recordID: ServiceRecord.ID) -> UUID {
        var value = blockID.uuid
        let key = recordID.uuid
        withUnsafeMutableBytes(of: &value) { bytes in
            withUnsafeBytes(of: key) { keyBytes in
                for index in bytes.indices { bytes[index] ^= keyBytes[index] }
            }
            // Still a version 4 UUID, as the API requires.
            bytes[6] = (bytes[6] & 0x0F) | 0x40
            bytes[8] = (bytes[8] & 0x3F) | 0x80
        }
        return UUID(uuid: value)
    }

    // MARK: Private

    private var pendingRange: Range<Int> {
        guard phase != .finished else { return blocks.endIndex..<blocks.endIndex }
        return (currentIndex.map { $0 + 1 } ?? 0)..<blocks.endIndex
    }

    private var nextRunnableIndex: Int? {
        pendingRange.first { !blocks[$0].isSkipped }
    }

    private func block(_ id: Block.ID) -> Block? {
        blocks.first { $0.id == id }
    }

    private func pendingIndex(of id: Block.ID) -> Int? {
        pendingRange.first { blocks[$0].id == id }
    }

    private mutating func begin(_ index: Int, personID: Person.ID?, at date: Date) {
        blocks[index].personID = personID
        blocks[index].startedAt = date
        currentIndex = index
        phase = .running
    }
}
