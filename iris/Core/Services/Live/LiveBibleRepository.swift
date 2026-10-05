//
//  LiveBibleRepository.swift
//  iris
//

import Foundation

/// Reina-Valera 1909 from `BibleStore`, read offline.
struct LiveBibleRepository: BibleRepository {
    let store: BibleStore
    let translationName = "Reina-Valera 1909"

    func availabilityUpdates() -> AsyncStream<BibleAvailability> {
        AsyncStream { continuation in
            let task = Task {
                for await availability in await store.availabilityUpdates() {
                    continuation.yield(availability)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func prepare() async {
        await store.ensureAvailable()
    }

    func books() async throws -> [BibleBook] {
        try await store.allBooks().map(\.info)
    }

    func verseCount(bookID: BibleBook.ID, chapter: Int) async throws -> Int {
        try await chapterText(bookID: bookID, chapter: chapter).count
    }

    func verses(bookID: BibleBook.ID, chapter: Int) async throws -> [BibleVerse] {
        try await chapterText(bookID: bookID, chapter: chapter)
            .enumerated()
            .map { BibleVerse(number: $0.offset + 1, text: $0.element) }
    }

    private func chapterText(bookID: BibleBook.ID, chapter: Int) async throws -> [String] {
        guard let book = try await store.allBooks().first(where: { $0.info.id == bookID }),
              book.chapters.indices.contains(chapter - 1) else { return [] }
        return book.chapters[chapter - 1]
    }
}
