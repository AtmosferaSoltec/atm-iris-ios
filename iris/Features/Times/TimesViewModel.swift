//
//  TimesViewModel.swift
//  iris
//

import Foundation
import Observation

/// Saved service times: records by date with their detail, and summaries with filters.
@Observable
final class TimesViewModel {
    enum Tab: Hashable, Identifiable, CaseIterable {
        case records, summaries

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .records: "Registros"
            case .summaries: "Resúmenes"
            }
        }
    }

    /// Records of one month, newest first.
    struct RecordSection: Identifiable, Equatable {
        let id: String
        /// "OCTUBRE 2026".
        let title: String
        let records: [ServiceRecord]
    }

    /// The person whose blocks are shown in the detail sheet.
    struct PersonDetail: Identifiable, Equatable {
        let id: Person.ID
    }

    // MARK: State

    private(set) var isLoading = true
    /// Newest first.
    private(set) var records: [ServiceRecord] = []
    private(set) var serviceTypes: [ServiceType] = []
    private(set) var people: [Person] = []
    private(set) var errorMessage: String?

    var tab: Tab = .records

    /// Quick filter of the records list; `nil` = all services.
    private(set) var recordTypeFilter: ServiceType.ID?
    private(set) var selectedRecordID: ServiceRecord.ID?
    var adjustment: DurationAdjustmentViewModel?
    var isConfirmingDeletion = false

    private(set) var summaryFilter = TimeStatistics.Filter()
    var isPickingMonth = false
    var pickedYear: Int
    var pickedMonth: Int
    var personDetail: PersonDetail?

    private let timeRecords: any TimeRecordRepository
    private let serviceTypeRepository: any ServiceTypeRepository
    private let peopleRepository: any PeopleRepository
    private let now: () -> Date
    private let calendar: Calendar
    private var saveTask: Task<Void, Never>?

    private static let spanish = Locale(identifier: "es")

    init(
        timeRecords: any TimeRecordRepository,
        serviceTypes: any ServiceTypeRepository,
        people: any PeopleRepository,
        now: @escaping () -> Date = { .now },
        calendar: Calendar = .current
    ) {
        self.timeRecords = timeRecords
        serviceTypeRepository = serviceTypes
        peopleRepository = people
        self.now = now
        self.calendar = calendar
        let today = calendar.dateComponents([.year, .month], from: now())
        pickedYear = today.year ?? 2026
        pickedMonth = today.month ?? 1
    }

    // MARK: Loading

    func load() async {
        guard isLoading else { return }
        let records = (try? await timeRecords.records()) ?? []
        let types = (try? await serviceTypeRepository.serviceTypes()) ?? []
        let people = (try? await peopleRepository.people()) ?? []
        apply(records: records, serviceTypes: types, people: people)
    }

    /// Installs loaded data. Also used by previews to start loaded.
    func apply(records: [ServiceRecord], serviceTypes: [ServiceType], people: [Person]) {
        self.records = records.sorted { $0.date > $1.date }
        self.serviceTypes = serviceTypes
        self.people = people
        selectedRecordID = filteredRecords.first?.id
        isLoading = false
    }

    // MARK: Shared texts

    func serviceName(_ id: ServiceType.ID) -> String {
        serviceTypes.first { $0.id == id }?.name ?? String(localized: "Servicio eliminado")
    }

    /// `nil` when the service type was deleted.
    func serviceColor(_ id: ServiceType.ID) -> UInt32? {
        serviceTypes.first { $0.id == id }?.color
    }

    /// Current name, else the one saved with the record; "Persona eliminada" or "Sin responsable" otherwise.
    func leaderName(of block: BlockRecord) -> String {
        if let name = block.resolvedPersonName(in: people) { return name }
        return block.personID == nil ? String(localized: "Sin responsable") : String(localized: "Persona eliminada")
    }

    func personName(_ id: Person.ID) -> String {
        if let person = people.first(where: { $0.id == id }) { return person.name }
        let saved = records.lazy.flatMap(\.blocks).first { $0.personID == id }?.personName
        return saved ?? String(localized: "Persona eliminada")
    }

    func initials(_ id: Person.ID) -> String {
        Person(id: id, name: personName(id)).initials
    }

    /// "dom 27 sept".
    func shortDate(_ date: Date) -> String {
        date.formatted(dateStyle.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "domingo, 27 de septiembre de 2026".
    func longDate(_ date: Date) -> String {
        date.formatted(dateStyle.weekday(.wide).day().month(.wide).year())
    }

    /// "+4:05" or "a tiempo".
    static func overtimeText(_ seconds: TimeInterval) -> String {
        seconds > 0 ? IrisDurationFormat.overtime(seconds) : String(localized: "a tiempo")
    }

    // MARK: Records

    var filteredRecords: [ServiceRecord] {
        guard let recordTypeFilter else { return records }
        return records.filter { $0.serviceTypeID == recordTypeFilter }
    }

    var recordSections: [RecordSection] {
        var sections: [RecordSection] = []
        for record in filteredRecords {
            let parts = calendar.dateComponents([.year, .month], from: record.date)
            let id = "\(parts.year ?? 0)-\(parts.month ?? 0)"
            if sections.last?.id == id {
                let last = sections.removeLast()
                sections.append(RecordSection(id: id, title: last.title, records: last.records + [record]))
            } else {
                sections.append(RecordSection(id: id, title: monthTitle(record.date).uppercased(with: Self.spanish), records: [record]))
            }
        }
        return sections
    }

    /// Types that appear in the records, for the quick filter.
    var recordFilterOptions: [ServiceType] {
        let used = Set(records.map(\.serviceTypeID))
        return serviceTypes.filter { used.contains($0.id) }
    }

    var recordFilterTitle: String {
        recordTypeFilter.map { serviceName($0) } ?? String(localized: "Todos los servicios")
    }

    var selectedRecord: ServiceRecord? {
        filteredRecords.first { $0.id == selectedRecordID }
    }

    /// Common scale for the bars of a record's blocks.
    func barScale(for record: ServiceRecord) -> TimeInterval {
        max(1, record.blocks.filter { $0.status != .skipped }.map { max($0.plannedSeconds, $0.actualSeconds) }.max() ?? 1)
    }

    func setRecordFilter(_ typeID: ServiceType.ID?) {
        recordTypeFilter = typeID
        if selectedRecord == nil { selectedRecordID = filteredRecords.first?.id }
    }

    func selectRecord(_ id: ServiceRecord.ID) {
        selectedRecordID = id
    }

    func beginAdjustment(of block: BlockRecord, in record: ServiceRecord) {
        adjustment = DurationAdjustmentViewModel(blockName: block.name, plannedSeconds: block.plannedSeconds, actualSeconds: block.actualSeconds) { [weak self] seconds in
            self?.adjustment = nil
            Task { await self?.adjustDuration(of: block.id, in: record.id, to: seconds) }
        }
    }

    /// Saves a corrected duration; the block is marked "Ajustado".
    func adjustDuration(of blockID: BlockRecord.ID, in recordID: ServiceRecord.ID, to seconds: TimeInterval) async {
        await updateBlock(blockID, in: recordID) { block in
            block.actualSeconds = max(0, seconds)
            block.status = .adjusted
        }
    }

    /// Corrects who led a block; the saved name follows the person.
    func changeLeader(of blockID: BlockRecord.ID, in recordID: ServiceRecord.ID, to personID: Person.ID?) async {
        let name = personID.flatMap { id in people.first { $0.id == id }?.name }
        await updateBlock(blockID, in: recordID) { block in
            block.personID = personID
            block.personName = name
        }
    }

    func requestDeleteSelected() {
        isConfirmingDeletion = true
    }

    func deleteSelected() async {
        guard let record = selectedRecord else { return }
        records.removeAll { $0.id == record.id }
        selectedRecordID = filteredRecords.first?.id
        do {
            try await timeRecords.delete(record.id)
        } catch {
            errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
        }
    }

    // MARK: Summaries

    var statistics: TimeStatistics {
        TimeStatistics(records: records, filter: summaryFilter, now: now(), calendar: calendar)
    }

    static let periods: [TimeStatistics.Period] = [.thisMonth, .lastMonth, .last3Months, .thisYear, .all]

    func periodTitle(_ period: TimeStatistics.Period) -> String {
        switch period {
        case .thisMonth: String(localized: "Este mes")
        case .lastMonth: String(localized: "Mes anterior")
        case .last3Months: String(localized: "Últimos 3 meses")
        case .thisYear: String(localized: "Este año")
        case .all: String(localized: "Todo")
        case let .month(year, month):
            "\(monthName(month)) \(year)"
        }
    }

    var serviceFilterTitle: String {
        summaryFilter.serviceTypeID.map { serviceName($0) } ?? String(localized: "Todos los servicios")
    }

    var blockFilterTitle: String {
        summaryFilter.blockName ?? String(localized: "Todos los bloques")
    }

    var personFilterTitle: String {
        summaryFilter.personID.map { personName($0) } ?? String(localized: "Todas las personas")
    }

    /// Distinct block names in the saved records, alphabetical.
    var blockNames: [String] {
        var names: [String: String] = [:]
        for block in records.flatMap(\.blocks) where names[block.name.nameKey] == nil {
            names[block.name.nameKey] = block.name
        }
        return names.values.sorted { $0.compare($1, options: .caseInsensitive, locale: Self.spanish) == .orderedAscending }
    }

    var filterPeople: [Person] {
        people.sorted { $0.name.compare($1.name, options: .caseInsensitive, locale: Self.spanish) == .orderedAscending }
    }

    /// Years offered by "Elegir mes…", from the oldest record to this year.
    var pickableYears: [Int] {
        let thisYear = calendar.component(.year, from: now())
        let oldest = records.last.map { calendar.component(.year, from: $0.date) } ?? thisYear
        return Array(min(oldest, thisYear)...thisYear)
    }

    /// "Octubre".
    func monthName(_ month: Int) -> String {
        var spanishCalendar = calendar
        spanishCalendar.locale = Self.spanish
        let symbols = spanishCalendar.standaloneMonthSymbols
        return symbols.indices.contains(month - 1) ? Self.capitalized(symbols[month - 1]) : ""
    }

    func setPeriod(_ period: TimeStatistics.Period) {
        summaryFilter.period = period
    }

    func setServiceFilter(_ id: ServiceType.ID?) {
        summaryFilter.serviceTypeID = id
    }

    func setBlockFilter(_ name: String?) {
        summaryFilter.blockName = name
    }

    func setPersonFilter(_ id: Person.ID?) {
        summaryFilter.personID = id
    }

    func beginPickingMonth() {
        if case let .month(year, month) = summaryFilter.period {
            pickedYear = year
            pickedMonth = month
        }
        isPickingMonth = true
    }

    func confirmPickedMonth() {
        summaryFilter.period = .month(year: pickedYear, month: pickedMonth)
        isPickingMonth = false
    }

    // KPIs

    var serviceCountText: String { "\(statistics.serviceCount)" }

    var averageDurationText: String { IrisDurationFormat.clock(statistics.averageDuration) }

    var averageOvertimeText: String { Self.overtimeText(statistics.averageOvertimePerService.rounded()) }

    /// "12 de 20 · 60 %".
    var overBlocksText: String {
        let (over, total) = statistics.overBlocks
        let percent = total > 0 ? Double(over) / Double(total) : 0
        return String(localized: "\(over) de \(total) · \(percent.formatted(.percent.precision(.fractionLength(0)).locale(Self.spanish)))")
    }

    func showPersonDetail(_ id: Person.ID) {
        personDetail = PersonDetail(id: id)
    }

    /// The person's blocks under the current filters.
    func personStatistics(_ id: Person.ID) -> TimeStatistics {
        var filter = summaryFilter
        filter.personID = id
        return TimeStatistics(records: records, filter: filter, now: now(), calendar: calendar)
    }

    /// "Se pasó en 5 de 8 bloques · promedio +6:20", in neutral words.
    func personSummary(_ id: Person.ID) -> String {
        let stats = personStatistics(id)
        guard let stat = stats.byPerson.first(where: { $0.personID == id }), stat.timesOver > 0 else {
            return String(localized: "A tiempo en sus \(stats.blockCount) bloques")
        }
        let average = IrisDurationFormat.overtime(stat.avgOvertimeWhenOver.rounded())
        return String(localized: "Se pasó en \(stat.timesOver) de \(stat.participations) bloques · promedio \(average)")
    }

    // MARK: Private

    /// "Octubre 2026", in the calendar's own time zone.
    private func monthTitle(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return "\(monthName(parts.month ?? 1)) \(parts.year ?? 0)"
    }

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: Self.spanish, calendar: calendar, timeZone: calendar.timeZone)
    }

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased(with: spanish) + text.dropFirst()
    }

    /// Changes one block locally right away, then saves; saves run in order.
    private func updateBlock(_ blockID: BlockRecord.ID, in recordID: ServiceRecord.ID, change: (inout BlockRecord) -> Void) async {
        guard let recordIndex = records.firstIndex(where: { $0.id == recordID }),
              let blockIndex = records[recordIndex].blocks.firstIndex(where: { $0.id == blockID }) else { return }
        change(&records[recordIndex].blocks[blockIndex])
        let record = records[recordIndex]
        let previous = saveTask
        let task = Task { [timeRecords] in
            await previous?.value
            do {
                try await timeRecords.save(record)
            } catch {
                self.errorMessage = String(localized: "Algo salió mal. Inténtalo de nuevo.")
            }
        }
        saveTask = task
        await task.value
    }
}

/// "Ajustar duración": minutes and seconds for a block that was timed wrong.
@Observable
final class DurationAdjustmentViewModel: Identifiable {
    let blockName: String
    let plannedSeconds: TimeInterval
    var minutes: Int
    var seconds: Int

    private let onSave: (TimeInterval) -> Void

    init(blockName: String, plannedSeconds: TimeInterval, actualSeconds: TimeInterval, onSave: @escaping (TimeInterval) -> Void) {
        self.blockName = blockName
        self.plannedSeconds = plannedSeconds
        let total = Int(actualSeconds.rounded())
        minutes = total / 60
        seconds = total % 60
        self.onSave = onSave
    }

    var totalSeconds: TimeInterval { TimeInterval(minutes * 60 + seconds) }

    func save() {
        onSave(totalSeconds)
    }
}
