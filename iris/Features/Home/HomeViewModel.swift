//
//  HomeViewModel.swift
//  iris
//

import Foundation
import Observation

@Observable
final class HomeViewModel {
    struct LibraryCounts: Equatable {
        var lyrics = 0
        /// Songs in the "Música" folder of this iPad.
        var music = 0
        /// Images, videos and audio uploaded on the web.
        var media = 0
    }

    // MARK: State

    private(set) var isLoading = true
    private(set) var modules = ChurchModules()
    /// What exists in Iris today; the Módulos tile does not list what is switched off for everyone.
    private(set) var availableModules = ChurchModules()
    private(set) var serviceTypes: [ServiceType] = []
    private(set) var people: [Person] = []
    private(set) var recordCount = 0
    private(set) var library = LibraryCounts()
    private(set) var display: ExternalDisplay?
    var selectedServiceTypeID: ServiceType.ID?

    let context: SessionContext
    private let now: () -> Date

    // MARK: Dependencies

    private let moduleSettings: any ModuleSettingsRepository
    private let serviceTypeRepository: any ServiceTypeRepository
    private let peopleRepository: any PeopleRepository
    private let timeRecords: any TimeRecordRepository
    private let libraryRepository: any LibraryRepository
    private let displayOutput: any DisplayOutputService
    private let sync: any SyncService
    /// Reloads name, role and permissions (`GET /auth/me`).
    private let reloadSession: () async -> Void
    private let onNavigate: (SignedInNavigator.Route) -> Void

    /// Sync interval while Home is visible (contract §12).
    static let periodicSyncInterval: Duration = .seconds(300)

    init(
        session: SessionContext,
        moduleSettings: any ModuleSettingsRepository,
        serviceTypes: any ServiceTypeRepository,
        people: any PeopleRepository,
        timeRecords: any TimeRecordRepository,
        libraryRepository: any LibraryRepository,
        displayOutput: any DisplayOutputService,
        sync: any SyncService = MockSyncService(),
        reloadSession: @escaping () async -> Void = {},
        now: @escaping () -> Date = { .now },
        onNavigate: @escaping (SignedInNavigator.Route) -> Void
    ) {
        context = session
        self.sync = sync
        self.reloadSession = reloadSession
        self.moduleSettings = moduleSettings
        self.serviceTypeRepository = serviceTypes
        self.peopleRepository = people
        self.timeRecords = timeRecords
        self.libraryRepository = libraryRepository
        self.displayOutput = displayOutput
        self.now = now
        self.onNavigate = onNavigate
    }

    var session: UserSession { context.session }

    /// First download of the church on this iPad.
    var initialSync: InitialSyncState { sync.initialSync }

    var syncService: any SyncService { sync }

    // MARK: Greeting

    var greeting: String {
        switch session.calendar.component(.hour, from: now()) {
        case 5..<12: String(localized: "Buenos días,")
        case 12..<19: String(localized: "Buenas tardes,")
        default: String(localized: "Buenas noches,")
        }
    }

    var todayText: String {
        now().formatted(
            Date.FormatStyle(locale: Locale(identifier: "es"), calendar: session.calendar, timeZone: session.church.timeZone)
                .weekday(.wide).day().month(.wide)
        )
    }

    /// Initials of the first two words longer than two letters of the church name.
    var accountInitials: String { session.churchInitials }

    // MARK: Hero

    /// No service types yet: the hero invites to configure them.
    var needsServiceSetup: Bool { serviceTypes.isEmpty }

    var selectedServiceType: ServiceType? {
        serviceTypes.first { $0.id == selectedServiceTypeID }
    }

    /// Whether the selected type is scheduled for today.
    var isSelectedToday: Bool {
        selectedServiceType?.schedule?.weekday == session.calendar.component(.weekday, from: now())
    }

    var selectedScheduleText: String? {
        guard let schedule = selectedServiceType?.schedule else { return nil }
        guard isSelectedToday else { return IrisScheduleFormat.summary(schedule) }
        let time = IrisScheduleFormat.time(hour: schedule.hour, minute: schedule.minute)
        return String(localized: "Hoy · \(time)")
    }

    /// Time-tracking blocks of the selected type, only if the module is on.
    var selectedBlocks: [BlockTemplate] {
        guard modules.timeControl else { return [] }
        return selectedServiceType?.blocks ?? []
    }

    func personName(_ id: Person.ID?) -> String? {
        people.first { $0.id == id }?.name
    }

    // MARK: Tiles

    var timesSubtitle: String {
        switch recordCount {
        case 0: String(localized: "Aún no hay registros")
        case 1: String(localized: "1 servicio registrado")
        default: String(localized: "\(recordCount) servicios registrados")
        }
    }

    var timedServiceTypeCount: Int { serviceTypes.filter(\.tracksTime).count }

    // MARK: Intents

    /// Home appeared: loads with a spinner the first time, then refreshes silently.
    func appear() async {
        if isLoading {
            await load()
        } else {
            await refresh()
            // Back on Home: catch up with the web, roles included.
            await sync.syncNow(reason: .returnedHome)
            await reloadSession()
        }
    }

    /// Syncs every few minutes while Home is visible, until the calling task is cancelled.
    func runPeriodicSync() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.periodicSyncInterval)
            guard !Task.isCancelled else { return }
            await sync.syncNow(reason: .periodic)
        }
    }

    /// Reloads silently whenever the local copy changes, until the calling task is cancelled.
    func observeChanges() async {
        let streams = [
            moduleSettings.changes(), serviceTypeRepository.changes(), peopleRepository.changes(),
            timeRecords.changes(), libraryRepository.changes()
        ]
        for await _ in AsyncStream.merged(streams) {
            if isLoading { continue }
            await refresh()
            await refreshLibrary()
        }
    }

    /// Follows the TV connecting and disconnecting, until the calling task is cancelled.
    func observeDisplay() async {
        for await display in displayOutput.displayUpdates() {
            self.display = display
        }
    }

    func retryInitialSync() {
        Task { await sync.syncNow(reason: .manual) }
    }

    func load() async {
        guard isLoading else { return }
        modules = (try? await moduleSettings.modules()) ?? ChurchModules()
        availableModules = await moduleSettings.availableModules()
        let types = (try? await serviceTypeRepository.serviceTypes()) ?? []
        let people = (try? await peopleRepository.people()) ?? []
        let recordCount = (try? await timeRecords.records().count) ?? 0
        let library = LibraryCounts(
            lyrics: (try? await libraryRepository.lyrics().count) ?? 0,
            music: await libraryRepository.music().count,
            media: await libraryRepository.uploadedMedia().count
        )
        let display = await displayOutput.connectedDisplay()
        apply(modules: modules, serviceTypes: types, people: people, recordCount: recordCount, library: library, display: display)
    }

    /// Reloads what other screens can change, without the spinner. Keeps the selected type if it still exists.
    func refresh() async {
        guard !isLoading else { return }
        // Modules first: starting a service right after returning from Módulos must see the new switches.
        if let modules = try? await moduleSettings.modules() {
            self.modules = modules
        }
        availableModules = await moduleSettings.availableModules()
        let types = try? await serviceTypeRepository.serviceTypes()
        let people = try? await peopleRepository.people()
        let recordCount = try? await timeRecords.records().count

        // A failed request keeps what is already on screen.
        serviceTypes = types ?? serviceTypes
        self.people = people ?? self.people
        self.recordCount = recordCount ?? self.recordCount
        if selectedServiceType == nil {
            selectedServiceTypeID = suggestedServiceType(in: serviceTypes)?.id
        }
    }

    private func refreshLibrary() async {
        library = LibraryCounts(
            lyrics: (try? await libraryRepository.lyrics().count) ?? library.lyrics,
            music: await libraryRepository.music().count,
            media: await libraryRepository.uploadedMedia().count
        )
    }

    /// Installs loaded data. Also used by previews to start loaded.
    func apply(
        modules: ChurchModules,
        serviceTypes: [ServiceType],
        people: [Person],
        recordCount: Int,
        library: LibraryCounts,
        display: ExternalDisplay?
    ) {
        self.modules = modules
        self.serviceTypes = serviceTypes
        self.people = people
        self.recordCount = recordCount
        self.library = library
        self.display = display
        selectedServiceTypeID = suggestedServiceType(in: serviceTypes)?.id
        isLoading = false
    }

    func selectServiceType(_ id: ServiceType.ID) {
        selectedServiceTypeID = id
    }

    func startSelectedService() {
        guard let selectedServiceType else { return }
        onNavigate(.console(selectedServiceType))
    }

    func openServices() {
        onNavigate(.services)
    }

    func openLibrary() {
        onNavigate(.library)
    }

    func openModules() {
        onNavigate(.modules)
    }

    /// Tiempos and Personas exist only with the time-control module.
    func openTimes() {
        guard modules.timeControl else { return }
        onNavigate(.times)
    }

    func openPeople() {
        guard modules.timeControl else { return }
        onNavigate(.people)
    }

    // MARK: Private

    /// Today's next scheduled service, else the first type.
    private func suggestedServiceType(in types: [ServiceType]) -> ServiceType? {
        let calendar = session.calendar
        let weekday = calendar.component(.weekday, from: now())
        let minutesNow = calendar.component(.hour, from: now()) * 60 + calendar.component(.minute, from: now())
        let today = types
            .filter { $0.schedule?.weekday == weekday }
            .sorted { ($0.schedule?.hour ?? 0) < ($1.schedule?.hour ?? 0) }
        let upcoming = today.first { type in
            guard let schedule = type.schedule else { return false }
            // Still "current" up to two hours after it starts.
            return schedule.hour * 60 + schedule.minute + 120 >= minutesNow
        }
        return upcoming ?? today.last ?? types.first
    }
}
