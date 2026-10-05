//
//  TimeStatistics.swift
//  iris
//

import Foundation

/// Summaries of saved times for a period and optional service, block and person filters.
/// Skipped blocks never count; adjusted ones do. Overtime has no tolerance margin.
nonisolated struct TimeStatistics: Sendable {
    enum Period: Hashable, Sendable {
        case thisMonth, lastMonth, last3Months, thisYear, all
        case month(year: Int, month: Int)
    }

    struct Filter: Equatable, Sendable {
        var period: Period
        var serviceTypeID: ServiceType.ID?
        /// Compared ignoring case and accents.
        var blockName: String?
        var personID: Person.ID?

        init(period: Period = .last3Months, serviceTypeID: ServiceType.ID? = nil, blockName: String? = nil, personID: Person.ID? = nil) {
            self.period = period
            self.serviceTypeID = serviceTypeID
            self.blockName = blockName
            self.personID = personID
        }
    }

    /// One counted block, with the service it belongs to.
    struct Entry: Identifiable, Equatable, Sendable {
        let recordID: ServiceRecord.ID
        let date: Date
        let serviceTypeID: ServiceType.ID
        let block: BlockRecord

        var id: BlockRecord.ID { block.id }
    }

    struct PersonStat: Identifiable, Equatable, Sendable {
        let personID: Person.ID
        let participations: Int
        let timesOver: Int
        /// Average of the times the person went over; 0 if never.
        let avgOvertimeWhenOver: TimeInterval
        let maxOvertime: TimeInterval
        let totalOvertime: TimeInterval

        var id: Person.ID { personID }
    }

    struct BlockStat: Identifiable, Equatable, Sendable {
        /// Name as written in the most recent record.
        let name: String
        let timesOver: Int
        let total: Int
        let avgOvertimeWhenOver: TimeInterval
        let avgActual: TimeInterval
        let avgPlanned: TimeInterval

        var id: String { name.nameKey }
    }

    /// Counted blocks, newest record first.
    let entries: [Entry]
    /// Services with at least one counted block.
    let serviceCount: Int
    /// Per service, over its counted blocks.
    let averageDuration: TimeInterval
    /// Per service: counted real minus planned, when positive.
    let averageOvertimePerService: TimeInterval
    let overBlockCount: Int
    let blockCount: Int
    /// Highest total overtime first.
    let byPerson: [PersonStat]
    /// Most often over first.
    let byBlock: [BlockStat]

    var overBlocks: (over: Int, total: Int) { (overBlockCount, blockCount) }

    init(records: [ServiceRecord], filter: Filter, now: Date, calendar: Calendar) {
        let range = Self.dateRange(of: filter.period, now: now, calendar: calendar)
        let blockKey = filter.blockName?.nameKey

        var entries: [Entry] = []
        var services: [(actual: TimeInterval, planned: TimeInterval)] = []
        for record in records.sorted(by: { $0.date > $1.date }) {
            if let range, !range.contains(record.date) { continue }
            if let typeID = filter.serviceTypeID, record.serviceTypeID != typeID { continue }
            let counted = record.blocks.filter { block in
                block.status != .skipped
                    && (blockKey == nil || block.name.nameKey == blockKey)
                    && (filter.personID == nil || block.personID == filter.personID)
            }
            guard !counted.isEmpty else { continue }
            entries += counted.map { Entry(recordID: record.id, date: record.date, serviceTypeID: record.serviceTypeID, block: $0) }
            services.append((counted.reduce(0) { $0 + $1.actualSeconds }, counted.reduce(0) { $0 + $1.plannedSeconds }))
        }

        self.entries = entries
        serviceCount = services.count
        averageDuration = Self.average(services.map(\.actual))
        averageOvertimePerService = Self.average(services.map { max(0, $0.actual - $0.planned) })
        overBlockCount = entries.filter(\.block.isOver).count
        blockCount = entries.count
        byPerson = Self.personStats(entries)
        byBlock = Self.blockStats(entries)
    }

    /// `nil` for `.all`. Months start on day 1 at midnight in the given calendar.
    static func dateRange(of period: Period, now: Date, calendar: Calendar) -> Range<Date>? {
        func monthStart(_ date: Date, offset: Int) -> Date? {
            guard let start = calendar.dateInterval(of: .month, for: date)?.start else { return nil }
            return calendar.date(byAdding: .month, value: offset, to: start)
        }
        switch period {
        case .all:
            return nil
        case .thisMonth:
            guard let start = monthStart(now, offset: 0), let end = monthStart(now, offset: 1) else { return nil }
            return start..<end
        case .lastMonth:
            guard let start = monthStart(now, offset: -1), let end = monthStart(now, offset: 0) else { return nil }
            return start..<end
        case .last3Months:
            guard let start = monthStart(now, offset: -2), let end = monthStart(now, offset: 1) else { return nil }
            return start..<end
        case .thisYear:
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return nil }
            return interval.start..<interval.end
        case let .month(year, month):
            guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            return start..<end
        }
    }

    // MARK: Private

    private static func average(_ values: [TimeInterval]) -> TimeInterval {
        values.isEmpty ? 0 : values.reduce(0, +) / TimeInterval(values.count)
    }

    private static func personStats(_ entries: [Entry]) -> [PersonStat] {
        var byPerson: [Person.ID: [BlockRecord]] = [:]
        for entry in entries {
            guard let personID = entry.block.personID else { continue }
            byPerson[personID, default: []].append(entry.block)
        }
        return byPerson.map { personID, blocks in
            let overtimes = blocks.filter(\.isOver).map(\.overtimeSeconds)
            return PersonStat(
                personID: personID,
                participations: blocks.count,
                timesOver: overtimes.count,
                avgOvertimeWhenOver: average(overtimes),
                maxOvertime: overtimes.max() ?? 0,
                totalOvertime: overtimes.reduce(0, +)
            )
        }
        .sorted {
            if $0.totalOvertime != $1.totalOvertime { return $0.totalOvertime > $1.totalOvertime }
            if $0.timesOver != $1.timesOver { return $0.timesOver > $1.timesOver }
            if $0.participations != $1.participations { return $0.participations > $1.participations }
            return $0.personID.uuidString < $1.personID.uuidString
        }
    }

    private static func blockStats(_ entries: [Entry]) -> [BlockStat] {
        var order: [String] = []
        var groups: [String: [BlockRecord]] = [:]
        for entry in entries {
            let key = entry.block.name.nameKey
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(entry.block)
        }
        return order.compactMap { key in
            guard let blocks = groups[key], let name = blocks.first?.name else { return nil }
            let overtimes = blocks.filter(\.isOver).map(\.overtimeSeconds)
            return BlockStat(
                name: name,
                timesOver: overtimes.count,
                total: blocks.count,
                avgOvertimeWhenOver: average(overtimes),
                avgActual: average(blocks.map(\.actualSeconds)),
                avgPlanned: average(blocks.map(\.plannedSeconds))
            )
        }
        .sorted {
            if $0.timesOver != $1.timesOver { return $0.timesOver > $1.timesOver }
            return $0.name.compare($1.name, options: .caseInsensitive, locale: Locale(identifier: "es")) == .orderedAscending
        }
    }
}
