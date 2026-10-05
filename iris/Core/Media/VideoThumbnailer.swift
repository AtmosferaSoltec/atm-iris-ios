//
//  VideoThumbnailer.swift
//  iris
//

import AVFoundation
import UIKit

/// First frame of a cached video, saved as a JPEG in Caches so it is made only once.
actor VideoThumbnailer {
    static let shared = VideoThumbnailer()

    private let folder = URL.cachesDirectory.appending(path: "VideoThumbnails", directoryHint: .isDirectory)

    /// The thumbnail file for a local video, generating it the first time.
    func thumbnail(for video: URL) async -> URL? {
        let destination = folder.appending(path: video.deletingPathExtension().lastPathComponent + ".jpg")
        if FileManager.default.fileExists(atPath: destination.path) { return destination }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        guard let (image, _) = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)),
              let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.8) else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: destination, options: .atomic)
        return destination
    }
}
