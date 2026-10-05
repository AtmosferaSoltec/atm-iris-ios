//
//  BibleRepository.swift
//  iris
//

import Foundation

/// Whether the Bible text is on this iPad.
nonisolated enum BibleAvailability: Equatable, Sendable {
    case ready
    /// Downloading, 0…1.
    case downloading(progress: Double)
    /// Not downloaded and no connection.
    case needsConnection
    case failed(message: String)
}

/// Bible text source. Downloaded once from the API and read offline.
protocol BibleRepository {
    /// Display name of the translation, e.g. "Reina-Valera 1909".
    var translationName: String { get }
    /// The current availability, then every change, until the consuming task ends.
    func availabilityUpdates() -> AsyncStream<BibleAvailability>
    /// Starts (or retries) the download when the text is not here yet.
    func prepare() async
    func books() async throws -> [BibleBook]
    func verseCount(bookID: BibleBook.ID, chapter: Int) async throws -> Int
    func verses(bookID: BibleBook.ID, chapter: Int) async throws -> [BibleVerse]
}

extension BibleRepository {
    func availabilityUpdates() -> AsyncStream<BibleAvailability> {
        AsyncStream { continuation in
            continuation.yield(.ready)
            continuation.finish()
        }
    }

    func prepare() async {}
}
