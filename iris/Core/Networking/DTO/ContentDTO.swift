//
//  ContentDTO.swift
//  iris
//
//  API contract §10, §11 and §13.
//

import Foundation

nonisolated struct SongSectionDTO: Codable, Hashable, Sendable {
    let id: String
    let label: String?
    let text: String
}

nonisolated struct SongDTO: Codable, Hashable, Sendable {
    let id: String
    let title: String
    let author: String
    let copyright: String?
    let sections: [SongSectionDTO]
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct SongSummaryDTO: Codable, Hashable, Sendable {
    let id: String
    let title: String
    let author: String
    let sectionCount: Int
    let firstLine: String?
    let updatedAt: Date
}

nonisolated enum MediaKindDTO: String, TolerantStringEnum {
    case image, video, audio, unknown
}

nonisolated struct MediaAssetDTO: Codable, Hashable, Sendable {
    let id: String
    let kind: MediaKindDTO
    let title: String
    let description: String?
    let fileName: String
    let contentType: String
    let sizeBytes: Int64
    let durationSeconds: Double?
    let width: Int?
    let height: Int?
    let isBackground: Bool
    let createdAt: Date
    let updatedAt: Date
}

/// `GET /media/:id/download-url`.
nonisolated struct DownloadURLDTO: Codable, Hashable, Sendable {
    let url: URL
    let expiresAt: Date
}

nonisolated enum TestamentDTO: String, TolerantStringEnum {
    case old, new, unknown
}

nonisolated struct BibleTranslationDTO: Codable, Hashable, Sendable {
    let code: String
    let name: String
    let language: String
    let version: Int
    let sizeBytes: Int64
}

nonisolated struct BibleBookDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let testament: TestamentDTO
    let chapterCount: Int
    let position: Int
}

/// The whole translation: `chapters[c][v]` is the text of verse c+1:v+1.
nonisolated struct BibleDownloadDTO: Codable, Hashable, Sendable {
    nonisolated struct Book: Codable, Hashable, Sendable {
        let id: String
        let name: String
        let testament: TestamentDTO
        let chapterCount: Int
        let position: Int
        let chapters: [[String]]
    }

    let code: String
    let name: String
    let version: Int
    let books: [Book]
}
