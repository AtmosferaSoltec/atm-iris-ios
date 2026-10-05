//
//  BiblePickerViewModel.swift
//  iris
//

import Foundation
import Observation

/// Three-step picker: book → chapter → verse.
@Observable
final class BiblePickerViewModel: Identifiable {
    enum Step: Equatable {
        case book, chapter, verse
    }

    private(set) var step: Step = .book
    private(set) var books: [BibleBook] = []
    var testament: BibleBook.Testament = .new

    private(set) var selectedBook: BibleBook?
    private(set) var selectedChapter: Int?
    private(set) var verseCount = 0
    private(set) var isLoading = false
    /// The text must be on the iPad before anything can be picked.
    private(set) var availability: BibleAvailability = .ready

    private let repository: any BibleRepository
    private let onSelect: (BibleBook, Int, Int) -> Void

    init(repository: any BibleRepository, onSelect: @escaping (BibleBook, Int, Int) -> Void) {
        self.repository = repository
        self.onSelect = onSelect
    }

    // MARK: Presentation

    var translationName: String { repository.translationName }

    var title: String {
        switch step {
        case .book: String(localized: "Biblia")
        case .chapter: selectedBook?.name ?? ""
        case .verse: "\(selectedBook?.name ?? "") \(selectedChapter ?? 0)"
        }
    }

    var instruction: String {
        switch step {
        case .book: String(localized: "Elige un libro")
        case .chapter: String(localized: "Elige un capítulo")
        case .verse: String(localized: "Elige un versículo")
        }
    }

    var filteredBooks: [BibleBook] {
        books.filter { $0.testament == testament }
    }

    var chapters: [Int] {
        guard let selectedBook else { return [] }
        return Array(1...selectedBook.chapterCount)
    }

    var verses: [Int] {
        verseCount > 0 ? Array(1...verseCount) : []
    }

    // MARK: Intents

    /// "Descargando la Biblia… 40 %".
    var downloadText: String {
        guard case let .downloading(progress) = availability else { return "" }
        let percent = progress.formatted(.percent.precision(.fractionLength(0)).locale(Locale(identifier: "es")))
        return String(localized: "Descargando la Biblia… \(percent)")
    }

    /// Follows the download and loads the books once the text is here, until the calling task is cancelled.
    func load() async {
        var askedForDownload = false
        for await availability in repository.availabilityUpdates() {
            self.availability = availability
            // Opened before the background download finished: make sure one is running.
            if !askedForDownload, availability == .needsConnection {
                askedForDownload = true
                retryDownload()
            }
            if availability == .ready, books.isEmpty {
                books = (try? await repository.books()) ?? []
            }
        }
    }

    func retryDownload() {
        availability = .downloading(progress: 0)
        Task { await repository.prepare() }
    }

    /// Installs a state directly. Used by previews.
    func apply(availability: BibleAvailability) {
        self.availability = availability
    }

    func selectBook(_ book: BibleBook) {
        selectedBook = book
        step = .chapter
    }

    func selectChapter(_ chapter: Int) async {
        guard let selectedBook else { return }
        selectedChapter = chapter
        verseCount = 0
        step = .verse
        isLoading = true
        verseCount = (try? await repository.verseCount(bookID: selectedBook.id, chapter: chapter)) ?? 0
        isLoading = false
    }

    func selectVerse(_ verse: Int) {
        guard let selectedBook, let selectedChapter else { return }
        onSelect(selectedBook, selectedChapter, verse)
    }

    func back() {
        switch step {
        case .book: break
        case .chapter: step = .book
        case .verse: step = .chapter
        }
    }
}

extension BibleBook.Testament: Identifiable {
    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .old: "Antiguo Testamento"
        case .new: "Nuevo Testamento"
        }
    }
}
