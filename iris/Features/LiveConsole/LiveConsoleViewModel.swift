//
//  LiveConsoleViewModel.swift
//  iris
//

import AVFoundation
import Foundation
import Observation

@Observable
final class LiveConsoleViewModel {
    enum Phase: Equatable {
        case loading, loaded, failed(String)
    }

    /// Address of a slide inside the service.
    struct SlidePosition: Equatable {
        let itemID: ServiceItem.ID
        let slideIndex: Int
    }

    /// Music or video currently playing. Survives navigating to other items.
    struct Playback: Equatable {
        let itemID: ServiceItem.ID
        let kind: ServiceItem.Kind
        let title: String
        var duration: TimeInterval
        var elapsed: TimeInterval = 0
        var isPlaying = true
        var isLooping = false

        var progress: Double { duration > 0 ? elapsed / duration : 0 }
    }

    /// Last removed item, kept briefly so it can be restored.
    struct RemovedItem: Equatable {
        let item: ServiceItem
        let index: Int
    }

    /// One step of the block "breadcrumbs" under the running clock.
    struct BlockCrumb: Identifiable, Equatable {
        enum State: Equatable {
            case done(isOver: Bool), current, pending, skipped
        }

        let id: BlockTimer.Block.ID
        let name: String
        let state: State
        /// Real duration of finished blocks.
        let time: String?
    }

    // MARK: State

    private(set) var phase: Phase = .loading
    private(set) var service: ServicePlan?
    private(set) var backgrounds: [ProjectionBackground] = []
    private(set) var display: ExternalDisplay?
    /// How the projected lyrics look; loaded once at start, same for every console (contract §6).
    private(set) var typography = ProjectionSettings()
    /// Shown whenever no background is chosen (`selectedBackgroundID == nil`); `nil` means black.
    private(set) var defaultBackground: ProjectionBackground?

    /// Item open in the workspace (may differ from what is on the TV).
    private(set) var selectedItemID: ServiceItem.ID?
    /// Slide currently on the TV.
    private(set) var live: SlidePosition?
    /// When `true` the TV shows only the background, without text.
    private(set) var isScreenCleared = false
    private(set) var selectedBackgroundID: ProjectionBackground.ID?
    private(set) var playback: Playback?
    private(set) var recentlyRemoved: RemovedItem?

    var isPickingBackground = false
    var isConfirmingClear = false
    var biblePicker: BiblePickerViewModel?
    var addSheet: AddToServiceViewModel?

    /// Passage opened from the Bible picker, shown in the workspace like a service item.
    private(set) var scriptureItem: ServiceItem?

    // MARK: Block timer state

    /// Only when the church uses time control and the service type has blocks.
    private(set) var blockTimer: BlockTimer?
    /// Ticks every second while a block runs.
    private(set) var now: Date
    /// Leaders offered in the pickers; grows when someone is added from the console.
    private(set) var people: [Person]
    var responsiblePicker: ResponsiblePickerViewModel?
    var addBlockSheet: AddBlockViewModel?
    var isEditingPendingBlocks = false
    var isConfirmingFinish = false
    var isAskingTemplateUpdate = false
    var isConfirmingExit = false
    /// Built when the service ends; saved right away or after the template question.
    private(set) var finishedRecord: ServiceRecord?
    private(set) var isRecordSaved = false
    private(set) var isSavingRecord = false
    private(set) var recordError: String?
    /// Saved on the iPad but not yet on the API (no connection): "Se enviará cuando haya conexión".
    private(set) var isRecordPendingUpload = false
    private var savesTemplate = false
    private var pendingExit: (() -> Void)?

    let context: SessionContext
    var session: UserSession { context.session }
    /// Service type chosen on Home, if any.
    let serviceType: ServiceType?
    /// Church modules when the service started. What is off disappears from the console.
    let modules: ChurchModules

    private var undoDismissTask: Task<Void, Never>?

    // MARK: Dependencies

    private let servicePlanRepository: any ServicePlanRepository
    private let projectionSettings: any ProjectionSettingsRepository
    private let backgroundRepository: any BackgroundRepository
    private let bibleRepository: any BibleRepository
    private let libraryRepository: any LibraryRepository
    private let mediaPlayback: any MediaPlaybackService
    private let displayOutput: any DisplayOutputService
    private let serviceTypeRepository: any ServiceTypeRepository
    private let peopleRepository: any PeopleRepository
    private let timeRecords: any TimeRecordRepository
    private let clock: () -> Date

    init(
        session: SessionContext,
        serviceType: ServiceType? = nil,
        modules: ChurchModules,
        people: [Person] = [],
        servicePlanRepository: any ServicePlanRepository,
        projectionSettings: any ProjectionSettingsRepository,
        backgroundRepository: any BackgroundRepository,
        bibleRepository: any BibleRepository,
        libraryRepository: any LibraryRepository,
        mediaPlayback: any MediaPlaybackService,
        displayOutput: any DisplayOutputService,
        serviceTypes: any ServiceTypeRepository,
        peopleRepository: any PeopleRepository,
        timeRecords: any TimeRecordRepository,
        clock: @escaping () -> Date = { .now }
    ) {
        context = session
        self.serviceType = serviceType
        self.modules = modules
        self.people = people
        self.servicePlanRepository = servicePlanRepository
        self.projectionSettings = projectionSettings
        self.backgroundRepository = backgroundRepository
        self.bibleRepository = bibleRepository
        self.libraryRepository = libraryRepository
        self.mediaPlayback = mediaPlayback
        self.displayOutput = displayOutput
        serviceTypeRepository = serviceTypes
        self.peopleRepository = peopleRepository
        self.timeRecords = timeRecords
        self.clock = clock
        now = clock()
        // Timing a service ends in saving its record, which needs `records.write`.
        if modules.timeControl, session.can(.recordsWrite), let serviceType, serviceType.tracksTime {
            blockTimer = BlockTimer(template: serviceType.blocks)
        }
    }

    // MARK: Derived

    var items: [ServiceItem] { service?.items ?? [] }

    /// Whether the files behind the service's music, images and videos are on this iPad, by media id.
    private(set) var mediaDownloads: [String: MediaAsset.DownloadState] = [:]

    /// The open media item's file: music and videos added before downloading wait for it.
    var selectedMediaDownload: MediaAsset.DownloadState {
        guard let id = selectedItem?.mediaID else { return .ready }
        return mediaDownloads[id] ?? .ready
    }

    var serviceTitle: String? { serviceType?.name ?? service?.title }

    var showsBible: Bool { modules.bible }

    /// Music, images and videos: library tabs, media items and the mini player.
    var showsMultimedia: Bool { modules.multimedia }

    var selectedItem: ServiceItem? { item(id: selectedItemID) }

    /// `true` while a Bible passage is open; enables previous/next.
    var isShowingScripture: Bool {
        scriptureItem != nil && selectedItemID == scriptureItem?.id
    }

    /// Music, video and image items show a single stage instead of a slide grid.
    var isShowingMedia: Bool {
        guard let kind = selectedItem?.kind else { return false }
        return kind == .music || kind == .video || kind == .image
    }

    /// Whether the open media item is already playing or on screen.
    var isSelectedMediaActive: Bool {
        guard let selectedItem else { return false }
        switch selectedItem.kind {
        case .music, .video: return playback?.itemID == selectedItem.id
        case .image: return live?.itemID == selectedItem.id && !isScreenCleared
        default: return false
        }
    }

    var canGoPrevious: Bool { (live?.slideIndex ?? 0) > 0 }

    var canGoNext: Bool {
        guard let live, let item = item(id: live.itemID) else { return false }
        return live.slideIndex + 1 < item.slides.count
    }

    var liveSlideID: Slide.ID? { liveSlide?.id }

    var selectedBackground: ProjectionBackground? {
        backgrounds.first { $0.id == selectedBackgroundID }
    }

    var accountInitials: String { session.churchInitials }

    /// The frame currently on the TV.
    var liveFrame: ProjectionFrame {
        guard !isScreenCleared, let liveSlide else {
            return ProjectionFrame(background: selectedBackground, content: .blank)
        }
        return ProjectionFrame(background: selectedBackground, content: projectionContent(for: liveSlide))
    }

    /// Plain black card used in the workspace.
    func cardFrame(for slide: Slide) -> ProjectionFrame {
        ProjectionFrame(background: nil, content: projectionContent(for: slide))
    }

    func isLive(slideIndex: Int) -> Bool {
        guard let selectedItemID else { return false }
        return live == SlidePosition(itemID: selectedItemID, slideIndex: slideIndex)
    }

    func position(of item: ServiceItem) -> Int {
        (items.firstIndex { $0.id == item.id } ?? 0) + 1
    }

    // MARK: Loading

    func load() async {
        guard phase != .loaded else { return }
        phase = .loading
        do {
            // A service started from Home begins with an empty list; the sample plan is for previews.
            let plan: ServicePlan
            if let serviceType {
                plan = ServicePlan(id: UUID(), title: serviceType.name, date: clock(), items: [])
            } else {
                plan = try await servicePlanRepository.currentService()
            }
            let backgrounds = try await backgroundRepository.backgrounds()
            // A church that hasn't set one up yet just gets `ProjectionSettings()` (system/88/none).
            let typography = (try? await projectionSettings.settings()) ?? ProjectionSettings()
            let display = await displayOutput.connectedDisplay()
            apply(plan: plan, backgrounds: backgrounds, display: display, typography: typography)
        } catch {
            phase = .failed(String(localized: "No pudimos cargar el servicio."))
        }
    }

    /// Installs loaded data. Also used by previews to start in a loaded state.
    func apply(
        plan: ServicePlan,
        backgrounds: [ProjectionBackground],
        display: ExternalDisplay?,
        typography: ProjectionSettings = ProjectionSettings()
    ) {
        var plan = plan
        if !modules.multimedia {
            plan.items.removeAll { [.music, .image, .video].contains($0.kind) }
        }
        self.service = plan
        self.backgrounds = backgrounds
        self.display = display
        self.typography = typography
        displayOutput.setTypography(typography)
        // A new service starts exactly as the church set up in Proyección: the configured image or
        // gradient if there is one, pure black otherwise — never the first background by chance.
        selectedBackgroundID = typography.defaultBackgroundId.flatMap { id in
            backgrounds.first { $0.id == id }?.id
        }

        // Demo state: second item open, its second slide on screen.
        let opening = plan.items.dropFirst().first ?? plan.items.first
        selectedItemID = opening?.id
        live = opening.map { SlidePosition(itemID: $0.id, slideIndex: min(1, $0.slides.count - 1)) }

        phase = .loaded
        pushOutput()
    }

    // MARK: Presenting

    func selectItem(_ id: ServiceItem.ID) {
        selectedItemID = id
    }

    /// Sends a slide of the open item out. Text and images go to the TV;
    /// video goes to the TV and starts playing; music only starts playing.
    func goLive(slideIndex: Int) {
        guard let item = selectedItem, item.slides.indices.contains(slideIndex) else { return }
        let position = SlidePosition(itemID: item.id, slideIndex: slideIndex)

        switch item.slides[slideIndex].content {
        case let .audio(title, duration, url):
            startPlayback(of: item, kind: .music, title: title, duration: duration, url: url)
        case let .video(title, duration, url):
            show(position)
            startPlayback(of: item, kind: .video, title: title, duration: duration, url: url)
        case .text, .image:
            show(position)
        }
    }

    /// Single action of the media stage.
    func presentSelectedMedia() {
        goLive(slideIndex: 0)
    }

    func toggleClearScreen() {
        isScreenCleared.toggle()
        pushOutput()
    }

    func next() {
        guard canGoNext, let live else { return }
        show(SlidePosition(itemID: live.itemID, slideIndex: live.slideIndex + 1))
    }

    func previous() {
        guard canGoPrevious, let live else { return }
        show(SlidePosition(itemID: live.itemID, slideIndex: live.slideIndex - 1))
    }

    func presentBackgroundPicker() {
        isPickingBackground = true
    }

    /// `nil` is "Ninguno": pure black, chosen on purpose rather than the absence of a choice.
    func selectBackground(_ id: ProjectionBackground.ID?) {
        selectedBackgroundID = id
        isPickingBackground = false
        pushOutput()
    }

    // MARK: Playback

    func togglePlayPause() {
        guard var playback else { return }
        playback.isPlaying.toggle()
        playback.isPlaying ? mediaPlayback.resume() : mediaPlayback.pause()
        self.playback = playback
    }

    func restartPlayback() {
        seek(to: 0)
    }

    func toggleLooping() {
        guard var playback else { return }
        playback.isLooping.toggle()
        mediaPlayback.setLooping(playback.isLooping)
        self.playback = playback
    }

    func seek(to seconds: TimeInterval) {
        guard var playback else { return }
        playback.elapsed = min(max(0, seconds), playback.duration)
        mediaPlayback.seek(to: playback.elapsed)
        self.playback = playback
    }

    /// Stops playback. A stopped video leaves the TV showing only the background.
    func stopPlayback() {
        guard let playback else { return }
        mediaPlayback.stop()
        if playback.kind == .video, live?.itemID == playback.itemID {
            live = nil
            pushOutput()
        }
        self.playback = nil
    }

    /// The video on the TV, for the live preview.
    var videoPlayer: AVPlayer? { displayOutput.videoPlayer }

    /// Follows the TV connecting and disconnecting, until the calling task is cancelled.
    func observeDisplay() async {
        for await display in displayOutput.displayUpdates() {
            self.display = display
        }
    }

    /// Keeps elapsed time in step with playback until the calling task is cancelled:
    /// real positions from the live service, simulated ones with the mock.
    func runPlaybackClock() async {
        guard !mediaPlayback.reportsProgress else {
            for await progress in mediaPlayback.progressUpdates() {
                guard var playback, playback.itemID == progress.itemID else { continue }
                if progress.didFinish {
                    stopPlayback()
                    continue
                }
                playback.elapsed = progress.elapsed
                playback.duration = progress.duration > 0 ? progress.duration : playback.duration
                playback.isPlaying = progress.isPlaying
                self.playback = playback
            }
            return
        }
        let step: TimeInterval = 0.5
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(step))
            guard var playback, playback.isPlaying else { continue }
            playback.elapsed += step
            if playback.elapsed >= playback.duration {
                if playback.isLooping {
                    playback.elapsed = 0
                } else {
                    self.playback = playback
                    stopPlayback()
                    continue
                }
            }
            self.playback = playback
        }
    }

    // MARK: Editing the service

    func presentAddToService() {
        addSheet = AddToServiceViewModel(
            repository: libraryRepository,
            tabs: modules.multimedia ? AddToServiceViewModel.Tab.allCases : [.lyrics]
        ) { [weak self] items in
            self?.appendToService(items)
        }
    }

    /// Appends picked library items to the end of the service and opens the first one.
    /// Files not yet on this iPad start downloading; they stay here afterwards (contract §11).
    func appendToService(_ items: [ServiceItem]) {
        guard !items.isEmpty else { return }
        service?.items.append(contentsOf: items)
        selectedItemID = items.first?.id
        addSheet = nil

        let missing = items.filter { $0.mediaID != nil && $0.slides.first?.content.url == nil }
        guard !missing.isEmpty else { return }
        for item in missing where mediaDownloads[item.mediaID!] == nil {
            mediaDownloads[item.mediaID!] = .notDownloaded
        }
        let ids = missing.compactMap(\.mediaID)
        let library = libraryRepository
        Task {
            await library.download(ids)
            await refreshMediaFiles()
        }
    }

    /// Tries again a file that could not be downloaded.
    func retrySelectedMediaDownload() {
        guard let id = selectedItem?.mediaID else { return }
        mediaDownloads[id] = .notDownloaded
        let library = libraryRepository
        Task { await library.download([id]) }
    }

    /// Follows the library while the console is open: downloads finishing, files replaced or
    /// deleted on the web. Until the calling task is cancelled.
    func observeLibrary() async {
        await refreshMediaFiles()
        for await _ in libraryRepository.changes() {
            await refreshMediaFiles()
        }
    }

    func removeItem(_ id: ServiceItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items[index]
        service?.items.remove(at: index)

        if selectedItemID == id {
            selectedItemID = items.indices.contains(index) ? items[index].id : items.last?.id
        }
        if playback?.itemID == id { stopPlayback() }
        if live?.itemID == id {
            live = nil
            pushOutput()
        }

        recentlyRemoved = RemovedItem(item: removed, index: index)
        scheduleUndoDismissal()
    }

    func undoRemoval() {
        guard let recentlyRemoved else { return }
        service?.items.insert(recentlyRemoved.item, at: min(recentlyRemoved.index, items.count))
        selectedItemID = recentlyRemoved.item.id
        self.recentlyRemoved = nil
        undoDismissTask?.cancel()
    }

    func duplicateItem(_ id: ServiceItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let original = items[index]
        let copy = ServiceItem(
            kind: original.kind,
            title: original.title,
            subtitle: original.subtitle,
            slides: original.slides.map { Slide(label: $0.label, content: $0.content) }
        )
        service?.items.insert(copy, at: index + 1)
        selectedItemID = copy.id
    }

    func canMove(_ id: ServiceItem.ID, by offset: Int) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        return items.indices.contains(index + offset)
    }

    func moveItem(_ id: ServiceItem.ID, by offset: Int) {
        guard canMove(id, by: offset), let index = items.firstIndex(where: { $0.id == id }) else { return }
        service?.items.swapAt(index, index + offset)
    }

    /// Applies a drag-to-reorder result: moves `ids` before `target` (or to the end).
    func moveItems(_ ids: [ServiceItem.ID], before target: ServiceItem.ID?) {
        guard var list = service?.items else { return }
        let moving = ids.compactMap { id in list.first { $0.id == id } }
        list.removeAll { ids.contains($0.id) }
        let insertIndex = target.flatMap { id in list.firstIndex { $0.id == id } } ?? list.count
        list.insert(contentsOf: moving, at: insertIndex)
        service?.items = list
    }

    func requestClearService() {
        isConfirmingClear = true
    }

    func clearService() {
        if let playback, items.contains(where: { $0.id == playback.itemID }) { stopPlayback() }
        if let live, items.contains(where: { $0.id == live.itemID }) {
            self.live = nil
            pushOutput()
        }
        service?.items.removeAll()
        if !isShowingScripture { selectedItemID = nil }
        recentlyRemoved = nil
    }

    // MARK: Bible

    func presentBible() {
        guard modules.bible else { return }
        biblePicker = BiblePickerViewModel(repository: bibleRepository) { [weak self] book, chapter, verse in
            Task { await self?.presentScripture(book: book, chapter: chapter, verse: verse) }
        }
    }

    /// Loads the chapter, opens it in the workspace and puts the chosen verse on the TV.
    func presentScripture(book: BibleBook, chapter: Int, verse: Int) async {
        guard let verses = try? await bibleRepository.verses(bookID: book.id, chapter: chapter) else { return }
        let item = ServiceItem(
            kind: .scripture,
            title: "\(book.name) \(chapter)",
            subtitle: bibleRepository.translationName,
            slides: verses.map { verse in
                Slide(
                    label: String(localized: "Versículo \(verse.number)"),
                    content: .text(verse.text, footnote: "\(book.name) \(chapter):\(verse.number)")
                )
            }
        )
        scriptureItem = item
        selectedItemID = item.id
        biblePicker = nil
        show(SlidePosition(itemID: item.id, slideIndex: max(0, min(verse - 1, verses.count - 1))))
    }

    // MARK: Block timer

    var showsBlockTimer: Bool { blockTimer != nil }

    var isTimerRunning: Bool { blockTimer?.phase == .running }

    /// Today's blocks as a plan for the timeline before starting; skipped ones are left out.
    var plannedBlocks: [BlockTemplate] {
        (blockTimer?.blocks ?? []).filter { !$0.isSkipped }.map {
            BlockTemplate(id: $0.id, name: $0.name, plannedMinutes: $0.plannedMinutes, defaultPersonID: $0.personID)
        }
    }

    /// "4 bloques · 1 h y 10 min".
    var blocksSummaryText: String {
        let blocks = plannedBlocks
        return IrisDurationFormat.blocksSummary(count: blocks.count, seconds: blocks.reduce(0) { $0 + $1.plannedSeconds })
    }

    var currentBlock: BlockTimer.Block? { blockTimer?.currentBlock }

    /// Whole seconds of the running block.
    var currentElapsed: TimeInterval {
        guard let currentBlock, let blockTimer else { return 0 }
        return blockTimer.elapsed(of: currentBlock.id, now: now).rounded(.down)
    }

    var currentClockState: BlockTimer.ClockState {
        BlockTimer.ClockState(elapsed: currentElapsed, planned: currentBlock?.plannedSeconds ?? 0)
    }

    /// 0…1; full once the block runs over.
    var currentProgress: Double {
        guard let planned = currentBlock?.plannedSeconds, planned > 0 else { return 0 }
        return min(1, currentElapsed / planned)
    }

    /// "−21:18" remaining, or "+3:10" over.
    var currentDeltaText: String {
        let planned = currentBlock?.plannedSeconds ?? 0
        return currentElapsed > planned
            ? "+\(IrisDurationFormat.clock(currentElapsed - planned))"
            : "−\(IrisDurationFormat.clock(planned - currentElapsed))"
    }

    /// On the last block "Siguiente bloque" becomes "Terminar".
    var isOnLastBlock: Bool { blockTimer?.nextBlock == nil }

    var canSkipNextBlock: Bool { isTimerRunning && blockTimer?.nextBlock != nil }

    var breadcrumbs: [BlockCrumb] {
        guard let blockTimer else { return [] }
        return blockTimer.blocks.map { block in
            if block.id == blockTimer.currentBlock?.id {
                return BlockCrumb(id: block.id, name: block.name, state: .current, time: nil)
            }
            if block.isSkipped {
                return BlockCrumb(id: block.id, name: block.name, state: .skipped, time: nil)
            }
            if block.endedAt != nil {
                let elapsed = blockTimer.elapsed(of: block.id, now: now).rounded(.down)
                return BlockCrumb(
                    id: block.id,
                    name: block.name,
                    state: .done(isOver: elapsed > block.plannedSeconds),
                    time: IrisDurationFormat.clock(elapsed)
                )
            }
            return BlockCrumb(id: block.id, name: block.name, state: .pending, time: nil)
        }
    }

    var pendingBlocks: [BlockTimer.Block] { blockTimer?.pendingBlocks ?? [] }

    func personName(_ id: Person.ID?) -> String? {
        people.first { $0.id == id }?.name
    }

    /// "Servicio terminado · 1:26:10 (previsto 1:10:00 · +16:10)".
    var finishedSummary: String? {
        guard let record = finishedRecord else { return nil }
        let actual = IrisDurationFormat.clock(record.actualSeconds)
        let planned = IrisDurationFormat.clock(record.plannedSeconds)
        let delta = record.overtimeSeconds > 0
            ? IrisDurationFormat.overtime(record.overtimeSeconds)
            : String(localized: "a tiempo")
        return String(localized: "Servicio terminado · \(actual) (previsto \(planned) · \(delta))")
    }

    /// "Agregaste Santa Cena y omitiste Anuncios."
    var templateChangesMessage: String {
        guard let changes = blockTimer?.templateChanges else { return "" }
        var parts: [String] = []
        if !changes.added.isEmpty { parts.append(String(localized: "agregaste \(Self.list(changes.added))")) }
        if !changes.skipped.isEmpty { parts.append(String(localized: "omitiste \(Self.list(changes.skipped))")) }
        if !changes.edited.isEmpty { parts.append(String(localized: "cambiaste \(Self.list(changes.edited))")) }
        if changes.isReordered { parts.append(String(localized: "cambiaste el orden")) }
        let sentence = Self.list(parts)
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + "."
    }

    /// "▶ Comenzar": asks who leads the first block, then starts it.
    func startBlocks() {
        guard let blockTimer, blockTimer.phase == .notStarted, let first = blockTimer.nextBlock else { return }
        presentResponsiblePicker(for: first) { [weak self] personID in
            guard let self else { return }
            self.now = self.clock()
            self.blockTimer?.start(personID: personID, at: self.now)
        }
    }

    /// "Siguiente bloque": asks who leads the next one and advances; on the last block asks to finish.
    func goToNextBlock() {
        guard let blockTimer, blockTimer.phase == .running else { return }
        guard let next = blockTimer.nextBlock else {
            requestFinish()
            return
        }
        presentResponsiblePicker(for: next) { [weak self] personID in
            guard let self else { return }
            self.now = self.clock()
            self.blockTimer?.advance(nextPersonID: personID, at: self.now)
        }
    }

    /// Corrects who leads a block, also one already finished.
    func setLeader(_ personID: Person.ID?, of blockID: BlockTimer.Block.ID) {
        blockTimer?.setPerson(blockID, personID: personID)
    }

    func presentAddBlock() {
        addBlockSheet = AddBlockViewModel(people: people) { [weak self] name, minutes, personID in
            self?.blockTimer?.addBlock(name: name, plannedMinutes: minutes, personID: personID)
            self?.addBlockSheet = nil
        }
    }

    func skipNextBlock() {
        guard canSkipNextBlock, let next = blockTimer?.nextBlock else { return }
        blockTimer?.skip(next.id)
    }

    func presentPendingEditor() {
        isEditingPendingBlocks = true
    }

    func renamePendingBlock(_ id: BlockTimer.Block.ID, to name: String) {
        blockTimer?.updatePending(id, name: name, plannedMinutes: nil, personID: nil)
    }

    func setPendingMinutes(_ minutes: Int, of id: BlockTimer.Block.ID) {
        blockTimer?.updatePending(id, name: nil, plannedMinutes: min(max(minutes, 1), 240), personID: nil)
    }

    func setPendingLeader(_ personID: Person.ID?, of id: BlockTimer.Block.ID) {
        blockTimer?.updatePending(id, name: nil, plannedMinutes: nil, personID: .some(personID))
    }

    func toggleSkip(_ id: BlockTimer.Block.ID) {
        if pendingBlocks.first(where: { $0.id == id })?.isSkipped == true {
            blockTimer?.restore(id)
        } else {
            blockTimer?.skip(id)
        }
    }

    /// Applies a drag-to-reorder result among the pending blocks.
    func movePendingBlocks(_ ids: [BlockTimer.Block.ID], before target: BlockTimer.Block.ID?) {
        let pending = pendingBlocks
        let source = IndexSet(ids.compactMap { id in pending.firstIndex { $0.id == id } })
        let destination = target.flatMap { id in pending.firstIndex { $0.id == id } } ?? pending.count
        blockTimer?.movePending(from: source, to: destination)
    }

    func requestFinish() {
        isConfirmingFinish = true
    }

    /// Ends the service. When today's blocks differ from the template, asks first and saves after the answer.
    func finishService() async {
        guard var timer = blockTimer, timer.phase == .running else { return }
        now = clock()
        timer.finish(at: now)
        blockTimer = timer
        finishedRecord = makeRecord(from: timer)
        if timer.hasTemplateChanges {
            isAskingTemplateUpdate = true
        } else {
            await saveRecord(updatingTemplate: false)
        }
    }

    /// "Guardar en la plantilla" needs `serviceTypes.manage`; without it the question only offers "Solo hoy".
    var canSaveTemplate: Bool { context.can(.serviceTypesManage) }

    /// "Solo hoy" or "Guardar en la plantilla". Only times are saved, never the content used.
    func saveRecord(updatingTemplate requested: Bool) async {
        let updatingTemplate = requested && canSaveTemplate
        guard let blockTimer, let record = finishedRecord, let serviceType, !isSavingRecord, !isRecordSaved else { return }
        savesTemplate = updatingTemplate
        isSavingRecord = true
        recordError = nil
        do {
            if updatingTemplate {
                var updated = serviceType
                updated.blocks = blockTimer.updatedTemplate(serviceType.blocks)
                try await serviceTypeRepository.save(updated)
            }
            try await timeRecords.save(record)
            isRecordSaved = true
            Task { await watchRecordUpload(record.id) }
        } catch {
            recordError = String(localized: "No pudimos guardar los tiempos. Inténtalo de nuevo.")
        }
        isSavingRecord = false
        if isRecordSaved, let exit = pendingExit {
            pendingExit = nil
            exit()
        }
    }

    /// Follows the saved record until it reaches the API, so the finished state can say so.
    private func watchRecordUpload(_ id: ServiceRecord.ID) async {
        // Give the outbox a moment to send it before showing anything.
        try? await Task.sleep(for: .seconds(2))
        isRecordPendingUpload = await timeRecords.isPendingUpload(id)
        while isRecordPendingUpload, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            isRecordPendingUpload = await timeRecords.isPendingUpload(id)
        }
    }

    func retrySavingRecord() async {
        await saveRecord(updatingTemplate: savesTemplate)
    }

    /// "‹ Inicio" while a block runs asks first; otherwise leaves right away.
    func requestExit(then exit: @escaping () -> Void) {
        guard isTimerRunning else {
            exit()
            return
        }
        pendingExit = exit
        isConfirmingExit = true
    }

    /// "Terminar y guardar": leaves once the times are saved (after the template question, if any).
    func finishAndExit() async {
        await finishService()
    }

    func exitWithoutSaving() {
        let exit = pendingExit
        pendingExit = nil
        exit?()
    }

    func cancelExit() {
        pendingExit = nil
    }

    /// Advances the clock every second while a block runs, until the calling task is cancelled.
    func runBlockClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            if isTimerRunning { now = clock() }
        }
    }

    /// Installs a timer in any state. Used by previews.
    func apply(blockTimer: BlockTimer, now: Date) {
        self.blockTimer = blockTimer
        self.now = now
        if blockTimer.phase == .finished {
            finishedRecord = makeRecord(from: blockTimer)
            isRecordSaved = true
        }
    }

    // MARK: Private

    private func presentResponsiblePicker(for block: BlockTimer.Block, onConfirm: @escaping (Person.ID?) -> Void) {
        responsiblePicker = ResponsiblePickerViewModel(
            blockName: block.name,
            suggestedPersonID: block.personID,
            people: people,
            peopleRepository: peopleRepository,
            onPersonAdded: { [weak self] person in self?.people.append(person) },
            onConfirm: { [weak self] personID in
                self?.responsiblePicker = nil
                onConfirm(personID)
            }
        )
    }

    private func makeRecord(from timer: BlockTimer) -> ServiceRecord? {
        guard let serviceType else { return nil }
        let date = timer.blocks.compactMap(\.startedAt).min() ?? service?.date ?? clock()
        let names = Dictionary(people.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return timer.record(serviceTypeID: serviceType.id, serviceTypeName: serviceType.name, date: date, peopleNames: names)
    }

    /// "Santa Cena y Anuncios", "a, b y c".
    private static func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and).locale(Locale(identifier: "es")))
    }

    private var liveSlide: Slide? {
        guard let live, let item = item(id: live.itemID),
              item.slides.indices.contains(live.slideIndex) else { return nil }
        return item.slides[live.slideIndex]
    }

    private func item(id: ServiceItem.ID?) -> ServiceItem? {
        guard let id else { return nil }
        if let scriptureItem, scriptureItem.id == id { return scriptureItem }
        return items.first { $0.id == id }
    }

    /// Puts a position on the TV. Replacing a playing video pauses it; music keeps going.
    private func show(_ position: SlidePosition) {
        if var playback, playback.kind == .video, playback.itemID != position.itemID, playback.isPlaying {
            playback.isPlaying = false
            mediaPlayback.pause()
            self.playback = playback
        }
        live = position
        isScreenCleared = false
        pushOutput()
    }

    private func startPlayback(of item: ServiceItem, kind: ServiceItem.Kind, title: String, duration: String, url: URL?) {
        // Without Multimedia the mini player never appears.
        guard modules.multimedia else { return }
        // A library file still downloading waits for it (sample data has no file and plays as is).
        if let id = item.mediaID, (mediaDownloads[id] ?? .ready) != .ready { return }
        if playback?.itemID == item.id {
            // Already loaded: just make sure it is playing.
            if playback?.isPlaying == false { togglePlayPause() }
            return
        }
        mediaPlayback.stop()
        mediaPlayback.play(itemID: item.id, url: url, kind: kind, title: title)
        playback = Playback(itemID: item.id, kind: kind, title: title, duration: Self.seconds(from: duration))
    }

    /// Points the service's media items at their cached files and records how each download goes.
    private func refreshMediaFiles() async {
        let ids = Set(items.compactMap(\.mediaID))
        guard !ids.isEmpty else { return }
        var assets: [String: MediaAsset] = [:]
        for kind in [MediaAsset.Kind.music, .image, .video] {
            for asset in (try? await libraryRepository.media(of: kind)) ?? [] where ids.contains(asset.id) {
                assets[asset.id] = asset
            }
        }

        // The service may have changed during the reads: patch what is there now.
        guard var plan = service else { return }
        var changedItems: Set<ServiceItem.ID> = []
        for index in plan.items.indices {
            guard let id = plan.items[index].mediaID else { continue }
            let asset = assets[id]
            // Deleted on the web: it can no longer play.
            mediaDownloads[id] = asset?.downloadState ?? .failed
            let url = asset?.localURL
            for slideIndex in plan.items[index].slides.indices where plan.items[index].slides[slideIndex].content.url != url {
                plan.items[index].slides[slideIndex].content = plan.items[index].slides[slideIndex].content.replacingURL(url)
                changedItems.insert(plan.items[index].id)
            }
        }
        guard !changedItems.isEmpty else { return }
        service = plan
        if let live, changedItems.contains(live.itemID) { pushOutput() }
    }

    private func scheduleUndoDismissal() {
        undoDismissTask?.cancel()
        undoDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.recentlyRemoved = nil
        }
    }

    private func projectionContent(for slide: Slide) -> ProjectionFrame.Content {
        switch slide.content {
        case let .text(text, footnote): .text(text, footnote: footnote)
        case let .image(title, artwork, url): .image(title: title, artwork: artwork, url: url)
        case let .video(title, duration, url): .video(title: title, duration: duration, url: url)
        case let .audio(title, duration, url): .audio(title: title, duration: duration, url: url)
        }
    }

    private func pushOutput() {
        displayOutput.present(liveFrame)
    }

    /// Parses "m:ss" / "h:mm:ss" into seconds.
    private static func seconds(from duration: String) -> TimeInterval {
        duration.split(separator: ":").reduce(0) { $0 * 60 + (TimeInterval($1) ?? 0) }
    }
}
