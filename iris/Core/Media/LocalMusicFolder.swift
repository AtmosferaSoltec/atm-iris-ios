//
//  LocalMusicFolder.swift
//  iris
//
//  The songs the church keeps on this iPad. They are not uploaded anywhere: the iPad reads them from
//  the "Música" folder of the app, which the Files app shows under "En mi iPad › Iris".
//

import AVFoundation
import UIKit

nonisolated enum LocalMusicFolder {
    static let folderName = "Música"

    /// Audio the player can open.
    static let fileExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac"]

    static var folderURL: URL {
        URL.documentsDirectory.appending(path: folderName, directoryHint: .isDirectory)
    }

    /// Creates the folder so it already exists when someone opens it from Files.
    static func ensureFolderExists() {
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    /// Every audio file in the folder (and its subfolders), by name.
    static func files() async -> [MediaAsset] {
        ensureFolderExists()
        let urls = audioFileURLs()
        var assets: [MediaAsset] = []
        for url in urls {
            let seconds = await duration(of: url)
            assets.append(
                MediaAsset(
                    id: "local:\(relativePath(of: url))",
                    kind: .music,
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: url.pathExtension.uppercased(),
                    duration: seconds.map { IrisDurationFormat.clock($0) },
                    artwork: [0x0F2417, 0x2F5233],
                    localURL: url,
                    downloadState: .ready,
                    durationSeconds: seconds
                )
            )
        }
        return assets.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Opens the folder in the Files app so songs can be copied in.
    @MainActor
    static func openInFiles() {
        ensureFolderExists()
        guard let url = URL(string: "shareddocuments://" + folderURL.path) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Private

    private static func audioFileURLs() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var urls: [URL] = []
        for case let url as URL in enumerator where fileExtensions.contains(url.pathExtension.lowercased()) {
            urls.append(url)
        }
        return urls
    }

    private static func relativePath(of url: URL) -> String {
        let base = folderURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path.hasPrefix(base) ? String(path.dropFirst(base.count + 1)) : url.lastPathComponent
    }

    private static func duration(of url: URL) async -> Double? {
        guard let time = try? await AVURLAsset(url: url).load(.duration), time.isNumeric else { return nil }
        let seconds = time.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }
}
