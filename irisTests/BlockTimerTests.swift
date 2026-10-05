//
//  BlockTimerTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// The block timer state machine, with injected dates.
struct BlockTimerTests {
    private let daniel = UUID()
    private let ana = UUID()
    private let template: [BlockTemplate]
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() {
        template = [
            BlockTemplate(name: "Bienvenida", plannedMinutes: 10),
            BlockTemplate(name: "Alabanzas", plannedMinutes: 15, defaultPersonID: ana),
            BlockTemplate(name: "Prédica", plannedMinutes: 40, defaultPersonID: daniel),
            BlockTemplate(name: "Anuncios", plannedMinutes: 5)
        ]
    }

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test func startAdvanceAndFinish() throws {
        var timer = BlockTimer(template: template)
        #expect(timer.phase == .notStarted)
        #expect(timer.nextBlock?.name == "Bienvenida")

        timer.start(personID: daniel, at: at(0))
        #expect(timer.phase == .running)
        #expect(timer.currentBlock?.name == "Bienvenida")
        #expect(timer.currentBlock?.personID == daniel)
        #expect(timer.elapsed(of: template[0].id, now: at(125)) == 125)

        timer.advance(nextPersonID: ana, at: at(580))
        #expect(timer.currentBlock?.name == "Alabanzas")
        #expect(timer.elapsed(of: template[0].id, now: at(9_999)) == 580)

        timer.advance(nextPersonID: nil, at: at(1_500))
        timer.advance(nextPersonID: nil, at: at(4_000))
        #expect(timer.currentBlock?.name == "Anuncios")
        #expect(timer.nextBlock == nil)

        timer.advance(nextPersonID: nil, at: at(4_300))
        #expect(timer.phase == .finished)
        #expect(timer.currentBlock == nil)
        #expect(timer.pendingBlocks.isEmpty)
    }

    @Test func overtimeHasNoMargin() {
        #expect(BlockTimer.ClockState(elapsed: 539, planned: 600) == .normal)
        #expect(BlockTimer.ClockState(elapsed: 540, planned: 600) == .warning)
        #expect(BlockTimer.ClockState(elapsed: 600, planned: 600) == .warning)
        #expect(BlockTimer.ClockState(elapsed: 600.9, planned: 600) == .warning)
        #expect(BlockTimer.ClockState(elapsed: 601, planned: 600) == .over)

        var timer = BlockTimer(template: [BlockTemplate(name: "Bienvenida", plannedMinutes: 10)])
        timer.start(personID: nil, at: at(0))
        #expect(timer.clockState(of: timer.blocks[0].id, now: at(601)) == .over)
        timer.finish(at: at(601))

        let record = timer.record(serviceTypeID: UUID(), date: t0, peopleNames: [:])
        #expect(record.blocks.first?.actualSeconds == 601)
        #expect(record.blocks.first?.isOver == true)
        #expect(record.overtimeSeconds == 1)
    }

    @Test func skippingExcludesFromTheTotalAndTheRun() {
        var timer = BlockTimer(template: template)
        timer.skip(template[1].id)
        timer.start(personID: nil, at: at(0))
        timer.advance(nextPersonID: daniel, at: at(600))
        #expect(timer.currentBlock?.name == "Prédica")

        timer.advance(nextPersonID: nil, at: at(3_000))
        timer.finish(at: at(3_300))
        let record = timer.record(serviceTypeID: UUID(), date: t0, peopleNames: [:])

        #expect(record.blocks.map(\.status) == [.completed, .skipped, .completed, .completed])
        #expect(record.plannedSeconds == (10 + 40 + 5) * 60)
        #expect(record.actualSeconds == 3_300)
    }

    @Test func blocksNotReachedAreSkippedButNotATemplateChange() {
        var timer = BlockTimer(template: template)
        timer.start(personID: nil, at: at(0))
        timer.finish(at: at(500))

        let record = timer.record(serviceTypeID: UUID(), date: t0, peopleNames: [:])
        #expect(record.blocks.map(\.status) == [.completed, .skipped, .skipped, .skipped])
        #expect(timer.hasTemplateChanges == false)
    }

    @Test func addingLiveMarksTemplateChanges() {
        var timer = BlockTimer(template: template)
        timer.start(personID: nil, at: at(0))
        #expect(timer.hasTemplateChanges == false)

        timer.addBlock(name: "Santa Cena", plannedMinutes: 12, personID: daniel)
        #expect(timer.blocks.map(\.name) == ["Bienvenida", "Santa Cena", "Alabanzas", "Prédica", "Anuncios"])
        #expect(timer.blocks[1].isAddedToday)
        #expect(timer.hasTemplateChanges)
        #expect(timer.templateChanges.added == ["Santa Cena"])
    }

    @Test func choosingAnotherLeaderIsNotATemplateChange() {
        var timer = BlockTimer(template: template)
        timer.start(personID: daniel, at: at(0))
        timer.updatePending(template[1].id, name: nil, plannedMinutes: nil, personID: .some(nil))
        #expect(timer.hasTemplateChanges == false)

        timer.updatePending(template[2].id, name: nil, plannedMinutes: 45, personID: nil)
        #expect(timer.templateChanges.edited == ["Prédica"])
    }

    @Test func recordHasTheRightStatusesAndNames() {
        var timer = BlockTimer(template: template)
        timer.skip(template[3].id)
        timer.start(personID: daniel, at: at(0))
        timer.advance(nextPersonID: ana, at: at(600))
        timer.advance(nextPersonID: daniel, at: at(1_500))
        timer.finish(at: at(4_000))

        let typeID = UUID()
        let record = timer.record(serviceTypeID: typeID, date: t0, peopleNames: [daniel: "Daniel Ruiz", ana: "Ana Torres"])
        #expect(record.serviceTypeID == typeID)
        #expect(record.date == t0)
        #expect(record.blocks.map(\.status) == [.completed, .completed, .completed, .skipped])
        #expect(record.blocks.map(\.actualSeconds) == [600, 900, 2_500, 0])
        #expect(record.blocks.map(\.personName) == ["Daniel Ruiz", "Ana Torres", "Daniel Ruiz", nil])
    }

    @Test func updatedTemplateAppliesTodaysChanges() {
        var timer = BlockTimer(template: template)
        timer.skip(template[3].id)
        timer.movePending(from: [2], to: 0)
        #expect(timer.blocks.map(\.name) == ["Prédica", "Bienvenida", "Alabanzas", "Anuncios"])

        timer.start(personID: nil, at: at(0))
        timer.addBlock(name: "Santa Cena", plannedMinutes: 12, personID: ana)
        timer.updatePending(template[0].id, name: "Bienvenida y oración", plannedMinutes: 8, personID: nil)

        let changes = timer.templateChanges
        #expect(changes.added == ["Santa Cena"])
        #expect(changes.skipped == ["Anuncios"])
        #expect(changes.edited == ["Bienvenida"])
        #expect(changes.isReordered)

        let updated = timer.updatedTemplate(template)
        #expect(updated.map(\.name) == ["Prédica", "Santa Cena", "Bienvenida y oración", "Alabanzas"])
        #expect(updated.map(\.plannedMinutes) == [40, 12, 8, 15])
        #expect(updated[0].defaultPersonID == daniel)
        #expect(updated[1].defaultPersonID == ana)
        #expect(updated[0].id == template[2].id)
    }

    @Test func correctingTheLeaderOfAFinishedBlock() {
        var timer = BlockTimer(template: template)
        timer.start(personID: daniel, at: at(0))
        timer.advance(nextPersonID: nil, at: at(600))

        timer.setPerson(template[0].id, personID: ana)
        #expect(timer.blocks[0].personID == ana)

        // Finished blocks can't be edited or skipped any more.
        timer.updatePending(template[0].id, name: "Otro", plannedMinutes: nil, personID: nil)
        timer.skip(template[0].id)
        #expect(timer.blocks[0].name == "Bienvenida")
        #expect(timer.blocks[0].isSkipped == false)
    }

    @Test func skippedBlocksCanBeRestored() {
        var timer = BlockTimer(template: template)
        timer.start(personID: nil, at: at(0))
        timer.skip(template[1].id)
        #expect(timer.nextBlock?.name == "Prédica")

        timer.restore(template[1].id)
        #expect(timer.nextBlock?.name == "Alabanzas")
        #expect(timer.hasTemplateChanges == false)
    }
}
