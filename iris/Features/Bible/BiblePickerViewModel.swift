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

    func load() async {
        guard books.isEmpty else { return }
        books = (try? await repository.books()) ?? []
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
