//
//  TimeStatisticsTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// Periods, overtime without margin, skipped blocks, person order and averages.
struct TimeStatisticsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private let culto = UUID()
    private let youth = UUID()
    private let ana = UUID()
    private let daniel = UUID()
    private let lucia = UUID()

    private var now: Date { date(2026, 10, 15, 12) }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 10, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func block(_ name: String, planned minutes: Int, actual seconds: TimeInterval, _ person: UUID?, _ status: BlockRecord.Status = .completed) -> BlockRecord {
        BlockRecord(name: name, plannedSeconds: TimeInterval(minutes * 60), actualSeconds: seconds, personID: person, status: status)
    }

    private func record(_ date: Date, type: UUID? = nil, _ blocks: [BlockRecord]) -> ServiceRecord {
        ServiceRecord(date: date, serviceTypeID: type ?? culto, blocks: blocks)
    }

    private func stats(_ records: [ServiceRecord], _ filter: TimeStatistics.Filter) -> TimeStatistics {
        TimeStatistics(records: records, filter: filter, now: now, calendar: calendar)
    }

    // MARK: Periods

    @Test func monthBorders() throws {
        let thisMonth = try #require(TimeStatistics.dateRange(of: .thisMonth, now: now, calendar: calendar))
        #expect(thisMonth.contains(date(2026, 10, 1, 0)))
        #expect(thisMonth.contains(date(2026, 9, 30, 23, 59, 59)) == false)
        #expect(thisMonth.contains(date(2026, 10, 31, 23, 59, 59)))
        #expect(thisMonth.contains(date(2026, 11, 1, 0)) == false)

        let lastMonth = try #require(TimeStatistics.dateRange(of: .lastMonth, now: now, calendar: calendar))
        #expect(lastMonth.lowerBound == date(2026, 9, 1, 0))
        #expect(lastMonth.upperBound == date(2026, 10, 1, 0))

        let last3 = try #require(TimeStatistics.dateRange(of: .last3Months, now: now, calendar: calendar))
        #expect(last3.lowerBound == date(2026, 8, 1, 0))
        #expect(last3.upperBound == date(2026, 11, 1, 0))

        let year = try #require(TimeStatistics.dateRange(of: .thisYear, now: now, calendar: calendar))
        #expect(year.lowerBound == date(2026, 1, 1, 0))

        let february = try #require(TimeStatistics.dateRange(of: .month(year: 2026, month: 2), now: now, calendar: calendar))
        #expect(february.upperBound == date(2026, 3, 1, 0))

        #expect(TimeStatistics.dateRange(of: .all, now: now, calendar: calendar) == nil)
    }

    @Test func periodSelectsRecords() {
        let records = [
            record(date(2026, 10, 1, 0), [block("Prédica", planned: 40, actual: 2_400, daniel)]),
            record(date(2026, 9, 30, 23, 59, 59), [block("Prédica", planned: 40, actual: 2_400, daniel)]),
            record(date(2026, 7, 31, 10), [block("Prédica", planned: 40, actual: 2_400, daniel)]),
            record(date(2025, 12, 28), [block("Prédica", planned: 40, actual: 2_400, daniel)])
        ]
        #expect(stats(records, .init(period: .thisMonth)).serviceCount == 1)
        #expect(stats(records, .init(period: .lastMonth)).serviceCount == 1)
        #expect(stats(records, .init(period: .last3Months)).serviceCount == 2)
        #expect(stats(records, .init(period: .thisYear)).serviceCount == 3)
        #expect(stats(records, .init(period: .month(year: 2025, month: 12))).serviceCount == 1)
        #expect(stats(records, .init(period: .all)).serviceCount == 4)
    }

    // MARK: Rules

    @Test func overtimeHasNoMargin() {
        let records = [record(date(2026, 10, 4), [
            block("Bienvenida", planned: 10, actual: 601, ana),
            block("Anuncios", planned: 10, actual: 600, lucia)
        ])]
        let summary = stats(records, .init(period: .all))

        #expect(summary.overBlocks == (1, 2))
        #expect(summary.averageOvertimePerService == 1)
        #expect(summary.byPerson.first?.personID == ana)
        #expect(summary.byPerson.first?.totalOvertime == 1)
    }

    @Test func skippedBlocksNeverCountAdjustedOnesDo() {
        let records = [
            record(date(2026, 10, 4), [
                block("Prédica", planned: 40, actual: 2_700, daniel, .adjusted),
                block("Anuncios", planned: 5, actual: 0, nil, .skipped)
            ]),
            record(date(2026, 10, 11), [block("Anuncios", planned: 5, actual: 0, lucia, .skipped)])
        ]
        let summary = stats(records, .init(period: .all))

        #expect(summary.serviceCount == 1)
        #expect(summary.blockCount == 1)
        #expect(summary.averageDuration == 2_700)
        #expect(summary.averageOvertimePerService == 300)
        #expect(summary.byPerson.map(\.personID) == [daniel])
        #expect(summary.byBlock.map(\.name) == ["Prédica"])
    }

    @Test func peopleOrderedByTotalOvertime() throws {
        let records = [
            record(date(2026, 10, 4), [
                block("Alabanzas", planned: 15, actual: 900 + 100, ana),
                block("Prédica", planned: 40, actual: 2_400 + 500, daniel),
                block("Anuncios", planned: 5, actual: 280, lucia)
            ]),
            record(date(2026, 10, 11), [
                block("Alabanzas", planned: 15, actual: 900 + 200, ana),
                block("Prédica", planned: 40, actual: 2_300, daniel),
                block("Anuncios", planned: 5, actual: 300, lucia)
            ])
        ]
        let byPerson = stats(records, .init(period: .all)).byPerson

        #expect(byPerson.map(\.personID) == [daniel, ana, lucia])
        let anaStat = try #require(byPerson.first { $0.personID == ana })
        #expect(anaStat.participations == 2)
        #expect(anaStat.timesOver == 2)
        #expect(anaStat.avgOvertimeWhenOver == 150)
        #expect(anaStat.maxOvertime == 200)
        #expect(anaStat.totalOvertime == 300)
        let danielStat = try #require(byPerson.first { $0.personID == daniel })
        #expect(danielStat.timesOver == 1)
        #expect(danielStat.avgOvertimeWhenOver == 500)
        #expect(byPerson.last?.timesOver == 0)
    }

    @Test func averages() {
        let records = [
            record(date(2026, 10, 4), [block("Bienvenida", planned: 30, actual: 1_800, ana), block("Prédica", planned: 30, actual: 1_800, daniel)]),
            record(date(2026, 10, 11), [block("Bienvenida", planned: 30, actual: 2_100, ana), block("Prédica", planned: 30, actual: 2_100, daniel)])
        ]
        let summary = stats(records, .init(period: .all))

        #expect(summary.averageDuration == 3_900)
        #expect(summary.averageOvertimePerService == 300)

        let bienvenida = summary.byBlock.first { $0.name == "Bienvenida" }
        #expect(bienvenida?.avgActual == 1_950)
        #expect(bienvenida?.avgPlanned == 1_800)
        #expect(bienvenida?.timesOver == 1)
        #expect(bienvenida?.total == 2)
    }

    // MARK: Filters

    @Test func blockFilterIgnoresCaseAndAccents() {
        let records = [
            record(date(2026, 10, 4), [block("Prédica", planned: 40, actual: 2_500, daniel), block("Anuncios", planned: 5, actual: 300, lucia)]),
            record(date(2026, 10, 11), [block("predica", planned: 40, actual: 2_300, daniel)])
        ]
        let summary = stats(records, .init(period: .all, blockName: "PREDICA "))

        #expect(summary.serviceCount == 2)
        #expect(summary.blockCount == 2)
        #expect(summary.byBlock.count == 1)
        #expect(summary.byBlock.first?.name == "predica")
        #expect(summary.averageDuration == 2_400)
    }

    @Test func serviceAndPersonFilters() {
        let records = [
            record(date(2026, 10, 4), type: culto, [block("Prédica", planned: 40, actual: 2_500, daniel), block("Alabanzas", planned: 15, actual: 900, ana)]),
            record(date(2026, 10, 10), type: youth, [block("Alabanzas", planned: 20, actual: 1_500, ana)])
        ]

        #expect(stats(records, .init(period: .all, serviceTypeID: youth)).serviceCount == 1)

        let anaOnly = stats(records, .init(period: .all, personID: ana))
        #expect(anaOnly.serviceCount == 2)
        #expect(anaOnly.blockCount == 2)
        #expect(anaOnly.entries.allSatisfy { $0.block.personID == ana })
        #expect(anaOnly.entries.first?.serviceTypeID == youth)
    }
}
