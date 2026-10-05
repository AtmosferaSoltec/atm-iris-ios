//
//  PermissionsAndTimeZoneTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// What each role sees (contract §3) and periods in the church's time zone.
struct PermissionsTests {
    private func screens(_ role: UserSession.Role) -> (modules: Bool, services: Bool, people: Bool, times: Bool, template: Bool) {
        let store = InMemoryChurchStore()
        let context = SessionContext.preview(role: role)
        let modules = ModulesViewModel(moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero), session: context)
        let services = ServiceTypesViewModel(
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero),
            session: context
        )
        let people = PeopleViewModel(people: MockPeopleRepository(store: store, latency: .zero), timeRecords: MockTimeRecordRepository(store: store, latency: .zero), session: context)
        let times = TimesViewModel(
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            session: context
        )
        let console = LiveConsoleViewModel.makePreview(modules: ChurchModules())
        let consoleForRole = LiveConsoleViewModel(
            session: context, modules: ChurchModules(), servicePlanRepository: MockServicePlanRepository(latency: .zero),
            backgroundRepository: MockBackgroundRepository(), bibleRepository: MockBibleRepository(), libraryRepository: MockLibraryRepository(),
            mediaPlayback: MockMediaPlaybackService(), displayOutput: MockDisplayOutputService(),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero), peopleRepository: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
        _ = console
        return (modules.canManage, services.canManage, people.canManage, times.canManage, consoleForRole.canSaveTemplate)
    }

    @Test func ownerAndAdminManageEverything() {
        for role in [UserSession.Role.owner, .admin] {
            let visible = screens(role)
            #expect(visible.modules && visible.services && visible.people && visible.times && visible.template)
        }
    }

    @Test func operatorOnlyManagesPeople() {
        let visible = screens(.operator)
        #expect(!visible.modules)
        #expect(!visible.services)
        #expect(visible.people)
        #expect(!visible.times)
        #expect(!visible.template)
    }

    @Test func operatorCannotFlipModulesOrCreateServices() {
        let store = InMemoryChurchStore()
        let modules = ModulesViewModel(moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero), session: .preview(role: .operator))
        modules.apply(modules: ChurchModules())
        modules.setModule(.bible, isOn: false)
        #expect(modules.isOn(.bible))

        let services = ServiceTypesViewModel(
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero),
            session: .preview(role: .operator)
        )
        services.createServiceType()
        #expect(services.editor == nil)
        services.edit(store.serviceTypes[0])
        #expect(services.editor?.isReadOnly == true)
    }
}

struct ChurchTimeZoneTests {
    @Test func lateServiceOnTheLastDayStaysInItsMonth() throws {
        let lima = try #require(TimeZone(identifier: "America/Lima"))
        let calendar = Calendar.church(timeZone: lima)
        // 31 Oct 2026, 23:30 in Lima is already 1 Nov in UTC.
        let late = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 30)))
        let typeID = UUID()
        let record = ServiceRecord(date: late, serviceTypeID: typeID, blocks: [
            BlockRecord(name: "Vigilia", plannedSeconds: 600, actualSeconds: 700, personID: nil)
        ])

        let october = TimeStatistics(records: [record], filter: .init(period: .month(year: 2026, month: 10)), now: late, calendar: calendar)
        let november = TimeStatistics(records: [record], filter: .init(period: .month(year: 2026, month: 11)), now: late, calendar: calendar)
        #expect(october.entries.count == 1)
        #expect(november.entries.isEmpty)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(utc.component(.month, from: late) == 11)
    }

    @Test func homeUsesTheChurchDay() throws {
        // 2026-10-05 02:00 UTC is still Sunday the 4th in Lima.
        let instant = try #require(JSONCoding.date(from: "2026-10-05T02:00:00.000Z"))
        #expect(UserSession.preview.calendar.component(.weekday, from: instant) == 1)
    }
}
