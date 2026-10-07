//
//  BibleStoreTests.swift
//  irisTests
//
//  The Bible on the iPad: downloaded once, kept on disk, and repaired when the copy is incomplete
//  (an older build saved the metadata and then deleted the text, leaving an empty book list).
//

import Foundation
import Testing
@testable import iris

@MainActor
struct BibleStoreTests {
    private nonisolated static func download(version: Int) -> String {
        """
        {"code":"rvr1909","name":"Reina-Valera 1909","version":\(version),"books":[
          {"id":"GEN","name":"Génesis","testament":"old","chapterCount":1,"position":1,"chapters":[["En el principio crió Dios los cielos y la tierra.","Y la tierra estaba desadornada y vacía"]]},
          {"id":"JHN","name":"Juan","testament":"new","chapterCount":1,"position":2,"chapters":[["EN el principio era el Verbo"]]}
        ]}
        """
    }

    private static func server(version: Int = 1) -> StubServer {
        StubServer { request in
            switch request.path {
            case "/bible/translations":
                .data(#"[{"code":"rvr1909","name":"Reina-Valera 1909","language":"es","version":\#(version),"sizeBytes":400}]"#)
            case "/bible/translations/rvr1909/download":
                StubServer.Response(
                    status: 200,
                    body: Data("{\"data\":\(download(version: version))}".utf8),
                    headers: ["ETag": "\"rvr1909-\(version)\"", "Content-Type": "application/json"]
                )
            default:
                .error(404, code: "NOT_FOUND")
            }
        }
    }

    /// A folder reached through a symbolic link, like `/var` → `/private/var` on a device.
    private func linkedFolder() throws -> (folder: URL, cleanUp: () -> Void) {
        let manager = FileManager.default
        let real = URL.temporaryDirectory.appending(path: "bible-real-\(UUID().uuidString)", directoryHint: .isDirectory)
        let link = URL.temporaryDirectory.appending(path: "bible-link-\(UUID().uuidString)")
        try manager.createDirectory(at: real, withIntermediateDirectories: true)
        try manager.createSymbolicLink(at: link, withDestinationURL: real)
        return (link.appending(path: "Bible", directoryHint: .isDirectory), {
            try? manager.removeItem(at: link)
            try? manager.removeItem(at: real)
        })
    }

    private func files(in folder: URL) -> Set<String> {
        Set(((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []))
    }

    @Test func aDownloadKeepsTheTextOnDisk() async throws {
        let (folder, cleanUp) = try linkedFolder()
        defer { cleanUp() }
        let store = BibleStore(client: Self.server().client(), folder: folder)

        await store.ensureAvailable()

        #expect(files(in: folder) == ["rvr1909.meta.json", "rvr1909-v1.json"])
        let books = try await store.allBooks()
        #expect(books.map(\.info.id) == ["GEN", "JHN"])
        #expect(books.map(\.info.testament) == [.old, .new])
    }

    @Test func aNewVersionReplacesTheOldOneAndKeepsItsOwnText() async throws {
        let (folder, cleanUp) = try linkedFolder()
        defer { cleanUp() }
        await BibleStore(client: Self.server(version: 1).client(), folder: folder).ensureAvailable()

        // Next day: the API has version 2.
        let store = BibleStore(client: Self.server(version: 2).client(), folder: folder)
        await store.ensureAvailable(lastCheck: .distantPast)

        #expect(files(in: folder) == ["rvr1909.meta.json", "rvr1909-v2.json"])
        #expect(try await store.allBooks().count == 2)
    }

    @Test func metadataWithoutItsTextIsNotReadyAndIsDownloadedAgain() async throws {
        let (folder, cleanUp) = try linkedFolder()
        defer { cleanUp() }
        // What the iPad had: the metadata, no text.
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"version":1,"name":"Reina-Valera 1909","etag":"\"rvr1909-1\""}"#.utf8)
            .write(to: folder.appending(path: "rvr1909.meta.json"))
        let store = BibleStore(client: Self.server().client(), folder: folder)

        var updates = await store.availabilityUpdates().makeAsyncIterator()
        #expect(await updates.next() == .needsConnection)
        await #expect(throws: LocalWriteError.self) { try await store.allBooks() }

        await store.ensureAvailable()
        #expect(try await store.allBooks().count == 2)
    }

    @Test func thePickerShowsTheBooksOfAnIncompleteCopyAfterRepairingIt() async throws {
        let (folder, cleanUp) = try linkedFolder()
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"version":1,"name":"Reina-Valera 1909","etag":null}"#.utf8)
            .write(to: folder.appending(path: "rvr1909.meta.json"))
        let repository = LiveBibleRepository(store: BibleStore(client: Self.server().client(), folder: folder))
        let picker = BiblePickerViewModel(repository: repository) { _, _, _ in }

        let loading = Task { await picker.load() }
        defer { loading.cancel() }
        for _ in 0..<300 where picker.books.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(picker.availability == .ready)
        picker.testament = .old
        #expect(picker.filteredBooks.map(\.name) == ["Génesis"])
        picker.testament = .new
        #expect(picker.filteredBooks.map(\.name) == ["Juan"])
    }

    @Test func thePickerReadsVersesOfTheDownloadedText() async throws {
        let (folder, cleanUp) = try linkedFolder()
        defer { cleanUp() }
        let repository = LiveBibleRepository(store: BibleStore(client: Self.server().client(), folder: folder))
        await repository.prepare()

        let verses = try await repository.verses(bookID: "GEN", chapter: 1)
        #expect(verses.map(\.number) == [1, 2])
        #expect(verses.first?.text == "En el principio crió Dios los cielos y la tierra.")
        #expect(try await repository.verseCount(bookID: "JHN", chapter: 1) == 1)
    }
}
