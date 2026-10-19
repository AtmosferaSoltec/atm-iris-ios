//
//  LiveLibraryRepository.swift
//  iris
//
//  Songs (contract §10) and media (§11) from the local copy. The iPad only reads them;
//  they are created on the web. Tracks and videos download once they are in the plan or the service.
//

import Foundation

struct LiveLibraryRepository: LibraryRepository {
    let data: LiveChurchData
    let cache: MediaCache

    func changes() -> AsyncStream<Void> { data.changes(of: [.songs, .media]) }

    /// Ordered by title (name key). Each track comes with its state on this iPad; the synced media
    /// row wins over the copy inside the song, which can be older.
    func lyrics() async throws -> [LyricSheet] {
        let media = await data.store.all(.media, as: MediaAssetDTO.self)
        let filesByID = Dictionary(media.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var sheets: [LyricSheet] = []
        for dto in await data.store.all(.songs, as: SongDTO.self) {
            guard var sheet = try? LyricSheet(dto) else { continue }
            if let audio = dto.audio {
                let file = filesByID[audio.id] ?? audio
                sheet.audio = MediaAsset(file, state: await cache.state(for: file))
            }
            sheets.append(sheet)
        }
        return sheets
    }

    func media(of kind: MediaAsset.Kind) async throws -> [MediaAsset] {
        var assets: [MediaAsset] = []
        for dto in await data.store.all(.media, as: MediaAssetDTO.self) where MediaAsset.Kind(dto.kind) == kind {
            assets.append(MediaAsset(dto, state: await cache.state(for: dto)))
        }
        return assets
    }
}

extension LiveLibraryRepository {
    func download(_ ids: [MediaAsset.ID]) async { await cache.request(ids) }
}

struct LiveBackgroundRepository: BackgroundRepository {
    let library: any LibraryRepository

    /// The six gradients, then the church images marked as background that are already on this iPad.
    func backgrounds() async throws -> [ProjectionBackground] {
        let images = ((try? await library.media(of: .image)) ?? [])
            .filter { $0.isBackground && $0.localURL != nil }
            .map { ProjectionBackground(id: "media-\($0.id)", name: $0.title, colors: $0.artwork, isAnimated: false, imageURL: $0.localURL) }
        // A video background loops muted behind the lyrics (contract §11); same eligibility as images.
        let videos = ((try? await library.media(of: .video)) ?? [])
            .filter { $0.isBackground && $0.localURL != nil }
            .map { ProjectionBackground(id: "media-\($0.id)", name: $0.title, colors: $0.artwork, isAnimated: true, videoURL: $0.localURL) }
        return ProjectionBackground.gradients + images + videos
    }
}

nonisolated extension MediaAsset.Kind {
    init?(_ dto: MediaKindDTO) {
        switch dto {
        case .image: self = .image
        case .video: self = .video
        case .audio: self = .music
        case .unknown: return nil
        }
    }
}

nonisolated extension MediaAsset {
    init(_ dto: MediaAssetDTO, state: MediaCache.State) {
        let kind = MediaAsset.Kind(dto.kind) ?? .image
        let downloadState: DownloadState
        var localURL: URL?
        switch state {
        case .notDownloaded: downloadState = .notDownloaded
        case let .downloading(progress): downloadState = .downloading(progress: progress)
        case let .ready(url):
            downloadState = .ready
            localURL = url
        case .failed: downloadState = .failed
        }
        self.init(
            id: dto.id,
            kind: kind,
            title: dto.title,
            subtitle: Self.subtitle(dto, kind: kind),
            duration: dto.durationSeconds.map { IrisDurationFormat.clock($0) },
            artwork: Self.placeholder(for: dto.id),
            localURL: localURL,
            downloadState: downloadState,
            durationSeconds: dto.durationSeconds,
            width: dto.width,
            height: dto.height,
            isBackground: dto.isBackground
        )
    }

    /// "Ambiente para oración" (track description), "JPG · 1920 × 1080", "MP4 · 1920 × 1080".
    private static func subtitle(_ dto: MediaAssetDTO, kind: Kind) -> String {
        if kind == .music, let description = dto.description, !description.isEmpty { return description }
        let format = (dto.fileName as NSString).pathExtension.uppercased()
        guard let width = dto.width, let height = dto.height else { return format }
        return "\(format) · \(width) × \(height)"
    }

    /// Two dark stops picked from the id, shown until the thumbnail loads.
    private static func placeholder(for id: String) -> [UInt32] {
        let palettes: [[UInt32]] = [
            [0x2A1658, 0x4E2A8C], [0x3A1E08, 0x8C3A1E], [0x06283D, 0x0E5E6F],
            [0x0F2417, 0x2F5233], [0x5B2A3C, 0xC0694E], [0x131E5C, 0x4E5BFF]
        ]
        let seed = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palettes[seed % palettes.count]
    }
}
