//
//  MediaCache.swift
//  iris
//

import Foundation
import os

/// The church's images, videos and music on this iPad (contract §11).
/// Images and backgrounds download as soon as they sync; music and videos only once they are
/// requested (added to a service), and then stay here until they are deleted or replaced on the web.
/// Files live in `Application Support/Media/<churchID>/<mediaID>-<updatedAt>.<ext>`, outside iCloud backups.
actor MediaCache {
    nonisolated enum State: Hashable, Sendable {
        case notDownloaded
        case downloading(progress: Double)
        case ready(URL)
        case failed
    }

    /// Below this free space, videos stop downloading.
    static let minimumFreeBytes: Int64 = 1_000_000_000
    static let maxConcurrentDownloads = 2

    private let client: APIClient
    private let downloader: MediaDownloader
    private let root: URL
    private var churchID: String?
    private var states: [String: State] = [:]
    private var isRunning = false
    private var runsAgain: [MediaAssetDTO]?
    /// The latest synced list, so a request can start without waiting for the next sync.
    private var known: [MediaAssetDTO] = []
    /// Music and videos asked for on this iPad (this session, or already downloaded before).
    private var wanted: Set<String> = []
    /// Told when states change (throttled), so open screens refresh.
    private var onChange: @Sendable () -> Void = {}
    /// Told when videos are paused for lack of space (`true`) or resumed (`false`).
    private var onLowStorage: @Sendable (Bool) -> Void = { _ in }

    private static let logger = Logger(subsystem: "com.atmosfera.iris", category: "media")

    init(client: APIClient, downloader: MediaDownloader, root: URL = URL.applicationSupportDirectory.appending(path: "Media", directoryHint: .isDirectory)) {
        self.client = client
        self.downloader = downloader
        self.root = root
    }

    func setHandlers(onChange: @escaping @Sendable () -> Void, onLowStorage: @escaping @Sendable (Bool) -> Void) {
        self.onChange = onChange
        self.onLowStorage = onLowStorage
    }

    /// Switches the cache to a church; files of other churches are removed.
    func use(churchID: String) {
        guard self.churchID != churchID else { return }
        self.churchID = churchID
        states = [:]
        known = []
        wanted = []
        let manager = FileManager.default
        try? manager.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var folder = root
        try? folder.setResourceValues(values)
        for other in (try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] where other.lastPathComponent != churchID {
            try? manager.removeItem(at: other)
        }
    }

    /// Where a downloaded file lives, if it is already here.
    func localURL(for asset: MediaAssetDTO) -> URL? {
        guard let url = fileURL(for: asset), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func state(for asset: MediaAssetDTO) -> State {
        if let url = localURL(for: asset) { return .ready(url) }
        return states[asset.id] ?? .notDownloaded
    }

    /// Music and videos to have on this iPad (added to a service). Files already here are kept as they are.
    func request(_ ids: [String]) async {
        guard !ids.isEmpty else { return }
        wanted.formUnion(ids)
        // A failed one gets another chance when asked again.
        for id in ids where states[id] == .failed { states[id] = nil }
        onChange()
        await ensureDownloaded(known)
    }

    /// After a sync: removes files of deleted or replaced media and downloads what is missing:
    /// every image and background, and the music and videos that were requested.
    /// Images first, then music, then videos; at most two at a time.
    func ensureDownloaded(_ assets: [MediaAssetDTO]) async {
        guard churchID != nil else { return }
        known = assets
        if isRunning {
            runsAgain = assets
            return
        }
        isRunning = true
        var next: [MediaAssetDTO]? = assets
        while let batch = next {
            runsAgain = nil
            removeStaleFiles(keeping: batch)
            await download(batch)
            next = runsAgain
        }
        isRunning = false
    }

    /// Erases every cached file (sign-out).
    func clear() {
        churchID = nil
        states = [:]
        known = []
        wanted = []
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: Private

    private func download(_ assets: [MediaAssetDTO]) async {
        let missing = assets
            .filter { $0.kind != .unknown && localURL(for: $0) == nil && downloadsNow($0) }
            .sorted { Self.priority($0) < Self.priority($1) }
        guard !missing.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            var iterator = missing.makeIterator()
            var running = 0
            while running < Self.maxConcurrentDownloads, let asset = iterator.next() {
                group.addTask { await self.downloadOne(asset) }
                running += 1
            }
            while await group.next() != nil {
                if let asset = iterator.next() {
                    group.addTask { await self.downloadOne(asset) }
                }
            }
        }
    }

    private func downloadOne(_ asset: MediaAssetDTO) async {
        guard let destination = fileURL(for: asset) else { return }
        if asset.kind == .video, Self.freeBytes() < Self.minimumFreeBytes {
            onLowStorage(true)
            return
        }
        if asset.kind == .video { onLowStorage(false) }

        states[asset.id] = .downloading(progress: 0)
        onChange()
        do {
            let link = try await client.send(APIRequest(.get, "/media/\(asset.id)/download-url"), as: DownloadURLDTO.self)
            let id = asset.id
            try await downloader.download(link.url, to: destination) { [weak self] progress in
                Task { await self?.report(progress, for: id) }
            }
            states[asset.id] = .ready(destination)
        } catch {
            Self.logger.notice("No se pudo descargar \(asset.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            states[asset.id] = .failed
        }
        onChange()
    }

    /// Progress is reported in 10 % steps so screens are not redrawn for every chunk.
    private func report(_ progress: Double, for id: String) {
        let previous: Double
        if case let .downloading(value) = states[id] { previous = value } else { previous = 0 }
        guard progress - previous >= 0.1 || progress >= 1 else { return }
        states[id] = .downloading(progress: progress)
        onChange()
    }

    /// Images and backgrounds always; music and videos only when requested.
    private func downloadsNow(_ asset: MediaAssetDTO) -> Bool {
        asset.kind == .image || asset.isBackground || wanted.contains(asset.id)
    }

    private func removeStaleFiles(keeping assets: [MediaAssetDTO]) {
        guard let folder = churchFolder else { return }
        let current = Set(assets.compactMap { fileURL(for: $0)?.lastPathComponent })
        let ids = Set(assets.map(\.id))
        let manager = FileManager.default
        for file in (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        where !file.hasDirectoryPath {
            let id = Self.mediaID(ofFile: file.lastPathComponent)
            // Already on this iPad (or an older version of it): it stays wanted.
            if let id, ids.contains(id) { wanted.insert(id) }
            if !current.contains(file.lastPathComponent) { try? manager.removeItem(at: file) }
        }
        states = states.filter { ids.contains($0.key) }
        wanted.formIntersection(ids)
    }

    private var churchFolder: URL? {
        churchID.map { root.appending(path: $0, directoryHint: .isDirectory) }
    }

    private func fileURL(for asset: MediaAssetDTO) -> URL? {
        guard let folder = churchFolder else { return nil }
        let stamp = Int(asset.updatedAt.timeIntervalSince1970 * 1000)
        let ext = (asset.fileName as NSString).pathExtension.lowercased()
        let name = "\(asset.id)-\(stamp)" + (ext.isEmpty ? "" : ".\(ext)")
        return folder.appending(path: name)
    }

    /// `<mediaID>-<updatedAt>.<ext>` → the id (ids are UUIDs, so they hold dashes too).
    static func mediaID(ofFile name: String) -> String? {
        let base = (name as NSString).deletingPathExtension
        guard let dash = base.lastIndex(of: "-") else { return nil }
        return String(base[..<dash])
    }

    private static func priority(_ asset: MediaAssetDTO) -> Int {
        switch asset.kind {
        case .image: 0
        case .audio: 1
        case .video, .unknown: 2
        }
    }

    private static func freeBytes() -> Int64 {
        let values = try? URL.applicationSupportDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? .max
    }
}
