//
//  BibleStore.swift
//  iris
//

import Foundation
import os

/// The whole translation on disk (contract §13): downloaded once, checked for a new version at most once a day,
/// decoded lazily into memory and read offline.
actor BibleStore {
    nonisolated struct Book: Sendable {
        let info: BibleBook
        let chapters: [[String]]
    }

    private nonisolated struct Metadata: Codable, Sendable {
        let version: Int
        let etag: String?
        let name: String
    }

    let code: String
    private let client: APIClient
    private let folder: URL
    private let now: @Sendable () -> Date

    private var books: [Book]?
    private var availability: BibleAvailability
    private var downloadTask: Task<Void, Never>?
    private var subscribers: [UUID: AsyncStream<BibleAvailability>.Continuation] = [:]

    static let checkInterval: TimeInterval = 24 * 60 * 60

    private static let logger = Logger(subsystem: "com.atmosfera.iris", category: "bible")

    init(
        code: String = "rvr1909",
        client: APIClient,
        folder: URL = URL.applicationSupportDirectory.appending(path: "Bible", directoryHint: .isDirectory),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.code = code
        self.client = client
        self.folder = folder
        self.now = now
        availability = Self.hasCompleteCopy(in: folder, code: code) ? .ready : .needsConnection
    }

    // MARK: Availability

    func availabilityUpdates() -> AsyncStream<BibleAvailability> {
        let (stream, continuation) = AsyncStream.makeStream(of: BibleAvailability.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        subscribers[id] = continuation
        continuation.yield(availability)
        continuation.onTermination = { _ in Task { await self.unsubscribe(id) } }
        return stream
    }

    /// Downloads the text if it is not here. With `checkingForUpdates`, also asks the API for a newer
    /// version when the last check is older than a day (`lastCheck`), returning whether it checked.
    @discardableResult
    func ensureAvailable(lastCheck: Date? = nil) async -> Bool {
        if let downloadTask {
            await downloadTask.value
            return false
        }
        let isMissing = metadata() == nil
        let isDue = lastCheck.map { now().timeIntervalSince($0) > Self.checkInterval } ?? true
        guard isMissing || isDue else { return false }
        let task = Task { await self.download(revalidating: !isMissing) }
        downloadTask = task
        await task.value
        downloadTask = nil
        return true
    }

    // MARK: Reading

    func allBooks() throws -> [Book] {
        if let books { return books }
        guard let metadata = metadata() else { throw LocalWriteError(message: String(localized: "La Biblia aún no está en este iPad.")) }
        let data = try Data(contentsOf: textFile(version: metadata.version))
        let download = try JSONCoding.decoder.decode(BibleDownloadDTO.self, from: data)
        let loaded = download.books
            .sorted { $0.position < $1.position }
            .map { book in
                Book(
                    info: BibleBook(id: book.id, name: book.name, testament: BibleBook.Testament(book.testament), chapterCount: book.chapterCount),
                    chapters: book.chapters
                )
            }
        books = loaded
        return loaded
    }

    func translationName() -> String? {
        metadata()?.name
    }

    // MARK: Private

    private func download(revalidating: Bool) async {
        let current = metadata()
        if !revalidating { publish(.downloading(progress: 0)) }
        var request = APIRequest(.get, "/bible/translations/\(code)/download")
        if revalidating, let etag = current?.etag { request.headers["If-None-Match"] = etag }
        do {
            let expected = revalidating ? nil : await translationSize()
            let (data, response) = try await client.sendRaw(request, expectedBytes: expected) { [weak self] fraction in
                guard !revalidating else { return }
                Task { await self?.publish(.downloading(progress: fraction * 0.9)) }
            }
            if response.statusCode == 304 {
                publish(.ready)
                return
            }
            let envelope = try JSONCoding.decoder.decode(DataEnvelope<BibleDownloadDTO>.self, from: data)
            if !revalidating { publish(.downloading(progress: 0.9)) }
            try save(envelope.data, etag: response.value(forHTTPHeaderField: "ETag"))
            books = nil
            publish(.ready)
        } catch let error as APIError {
            Self.logger.notice("No se pudo descargar la Biblia: \(error.message, privacy: .public)")
            // A failed update keeps the copy already here.
            if current == nil { publish(error.isTransient ? .needsConnection : .failed(message: error.message)) }
        } catch {
            if current == nil { publish(.failed(message: String(localized: "Algo salió mal. Inténtalo de nuevo."))) }
        }
    }

    /// Writes the raw `BibleDownload` as `<code>-v<version>.json`, then its metadata, and drops older versions.
    private func save(_ download: BibleDownloadDTO, etag: String?) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONCoding.encoder.encode(download).write(to: textFile(version: download.version), options: .atomic)
        let metadata = Metadata(version: download.version, etag: etag, name: download.name)
        try JSONCoding.encoder.encode(metadata).write(to: metadataFile, options: .atomic)
        // Compared by name, never by URL: on a device the listing comes back as `/private/var/…` while
        // `folder` is `/var/…`, so comparing URLs deleted the text that had just been written.
        let current = textFile(version: download.version).lastPathComponent
        for file in (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        where file.lastPathComponent.hasPrefix("\(code)-v") && file.lastPathComponent != current {
            try? manager.removeItem(at: file)
        }
    }

    /// Size announced by `GET /bible/translations`, to show progress when the response has no length.
    private func translationSize() async -> Int64? {
        let translations = try? await client.send(APIRequest(.get, "/bible/translations"), as: [BibleTranslationDTO].self)
        return translations?.first { $0.code == code }?.sizeBytes
    }

    /// The metadata of the copy on disk, only when its text is there too. A metadata file without its
    /// text (left by an older build) counts as no copy, so the next `ensureAvailable` downloads it again.
    private func metadata() -> Metadata? {
        Self.completeMetadata(in: folder, code: code)
    }

    private nonisolated static func completeMetadata(in folder: URL, code: String) -> Metadata? {
        guard let data = try? Data(contentsOf: folder.appending(path: "\(code).meta.json")),
              let metadata = try? JSONCoding.decoder.decode(Metadata.self, from: data),
              FileManager.default.fileExists(atPath: folder.appending(path: "\(code)-v\(metadata.version).json").path)
        else { return nil }
        return metadata
    }

    private nonisolated static func hasCompleteCopy(in folder: URL, code: String) -> Bool {
        completeMetadata(in: folder, code: code) != nil
    }

    private var metadataFile: URL { folder.appending(path: "\(code).meta.json") }

    private func textFile(version: Int) -> URL { folder.appending(path: "\(code)-v\(version).json") }

    private func publish(_ availability: BibleAvailability) {
        self.availability = availability
        for continuation in subscribers.values { continuation.yield(availability) }
    }

    private func unsubscribe(_ id: UUID) {
        subscribers[id] = nil
    }
}
