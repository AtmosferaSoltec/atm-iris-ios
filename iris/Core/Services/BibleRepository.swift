//
//  BibleRepository.swift
//  iris
//

import Foundation

/// Bible text source. Local in V1, API or bundled translations later.
protocol BibleRepository {
    /// Display name of the translation, e.g. "Reina-Valera 1909".
    var translationName: String { get }
    func books() async throws -> [BibleBook]
    func verseCount(bookID: BibleBook.ID, chapter: Int) async throws -> Int
    func verses(bookID: BibleBook.ID, chapter: Int) async throws -> [BibleVerse]
}
