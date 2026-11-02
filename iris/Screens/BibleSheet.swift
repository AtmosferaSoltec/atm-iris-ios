//
//  BibleSheet.swift
//  iris
//

import SwiftUI

/// Where the last passage came from: the sheet reopens on that book's chapters, the chapter marked.
struct BiblePlace: Equatable {
    var bookId: String
    var chapter: Int
}

/// The computer's Bible, read from here: book, chapter, verse, and it goes to the screens once. A passage never
/// joins the service; the verses around it stay as cards on the remote, so "the next one" is a tap away.
/// It reopens on the last book, so "now chapter 20" is one tap.
struct BibleSheet: View {
    let client: RemoteClient
    let state: RemoteState
    @Binding var place: BiblePlace?

    @Environment(\.dismiss) private var dismiss
    @State private var translation: String?
    @State private var books: [BibleBook] = []
    @State private var book: BibleBook?
    @State private var chapter: Int?
    @State private var verses: [BibleVerse] = []
    @State private var isLoading = false
    @State private var error: String?

    private var bibles: [RemoteState.Bible] { state.bibles ?? [] }
    private var activeTranslation: String? { translation ?? state.selectedBible ?? bibles.first?.code }

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            SheetHeader("Biblia") {
                if bibles.count > 1 {
                    Picker("Traducción", selection: Binding(
                        get: { activeTranslation ?? "" },
                        set: { translation = $0; chapter = nil; verses = [] }
                    )) {
                        ForEach(bibles) { bible in Text(bible.name).tag(bible.code) }
                    }
                    .pickerStyle(.menu)
                    .tint(IrisColor.coral)
                }
            }
            breadcrumb
            if let error {
                IrisBanner(style: .error, message: error)
            }
            if bibles.isEmpty {
                Text("No hay Biblias en la computadora. Impórtalas en Iris, en Configuración → Biblias.")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            } else if isLoading {
                ProgressView().tint(IrisColor.coral).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let book, let chapter {
                verseGrid(book: book, chapter: chapter)
            } else if let book {
                chapterGrid(book)
            } else {
                bookList
            }
            Spacer(minLength: 0)
        }
        .padding(IrisSpacing.lg)
        .frame(minWidth: 720, minHeight: 520)
        .task { await loadBooks() }
    }

    private var breadcrumb: some View {
        HStack(spacing: IrisSpacing.xs) {
            Button { book = nil; chapter = nil; verses = [] } label: { Text("Libros").padding(.horizontal, IrisSpacing.sm) }
                .buttonStyle(.irisGlass).fixedSize()
                .disabled(book == nil)
            if let book {
                Image(systemName: "chevron.right").foregroundStyle(IrisColor.textSecondary)
                Button { chapter = nil; verses = [] } label: { Text(book.name).padding(.horizontal, IrisSpacing.sm) }
                    .buttonStyle(.irisGlass).fixedSize()
                    .disabled(chapter == nil)
            }
            if let chapter {
                Image(systemName: "chevron.right").foregroundStyle(IrisColor.textSecondary)
                Text("Capítulo \(chapter)").font(IrisFont.calloutEmphasized)
            }
        }
    }

    private var bookList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IrisSpacing.md) {
                bookSection("Antiguo Testamento", books.filter { $0.testament == "old" })
                bookSection("Nuevo Testamento", books.filter { $0.testament == "new" })
            }
        }
        .scrollIndicators(.hidden)
    }

    private func bookSection(_ title: String, _ list: [BibleBook]) -> some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xs) {
            Text(title.uppercased()).font(IrisFont.overline).tracking(IrisTracking.caps)
                .foregroundStyle(IrisColor.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: IrisSpacing.xs), count: 5), spacing: IrisSpacing.xs) {
                ForEach(list) { item in
                    tile(item.name) { book = item }
                }
            }
        }
    }

    private func chapterGrid(_ book: BibleBook) -> some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: IrisSpacing.xs), count: 10), spacing: IrisSpacing.xs) {
                ForEach(1...max(book.chapterCount, 1), id: \.self) { number in
                    tile("\(number)", isCurrent: place?.bookId == book.id && place?.chapter == number) {
                        Task { await loadChapter(book: book, chapter: number) }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func verseGrid(book: BibleBook, chapter: Int) -> some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: IrisSpacing.sm), count: 3), spacing: IrisSpacing.sm) {
                ForEach(verses.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) { verse in
                    Button {
                        guard let code = activeTranslation else { return }
                        client.send(.presentBible(translation: code, bookId: book.id, chapter: chapter, from: verse.number, to: verse.number))
                        place = BiblePlace(bookId: book.id, chapter: chapter)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                            Text("\(book.name) \(chapter):\(verse.number)")
                                .font(IrisFont.caption)
                                .foregroundStyle(IrisColor.textSecondary)
                            Text(verse.text)
                                .font(IrisFont.callout)
                                .foregroundStyle(.white)
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(IrisSpacing.sm)
                        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                        .background(.black, in: RoundedRectangle(cornerRadius: IrisRadius.sm))
                        .overlay(RoundedRectangle(cornerRadius: IrisRadius.sm).strokeBorder(IrisColor.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.irisPressable)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func tile(_ title: String, isCurrent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(IrisFont.callout)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isCurrent ? IrisColor.surfaceRaised : IrisColor.surface, in: RoundedRectangle(cornerRadius: IrisRadius.sm))
                .overlay(RoundedRectangle(cornerRadius: IrisRadius.sm).strokeBorder(isCurrent ? IrisColor.coral : .clear, lineWidth: 2))
        }
        .buttonStyle(.irisPressable)
    }

    private func loadBooks() async {
        guard books.isEmpty, !bibles.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            books = try await client.request(["kind": "bible-books"]).books ?? []
            if book == nil, let place { book = books.first { $0.id == place.bookId } }
        } catch {
            self.error = (error as? RemoteFailure)?.message ?? "No pudimos leer la Biblia."
        }
    }

    private func loadChapter(book: BibleBook, chapter: Int) async {
        guard let code = activeTranslation else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            verses = try await client.request(["kind": "bible-chapter", "translation": code, "bookId": book.id, "chapter": chapter]).verses ?? []
            self.chapter = chapter
        } catch {
            self.error = (error as? RemoteFailure)?.message ?? "No pudimos leer ese capítulo."
        }
    }
}
