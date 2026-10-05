//
//  LocalImage.swift
//  iris
//

import ImageIO
import SwiftUI
import UIKit

/// A cached image file decoded at a bounded size with ImageIO, off the main thread.
struct LocalImage: View {
    let url: URL
    /// Longest side in pixels to decode; keeps thumbnails from filling memory.
    let maxPixelSize: CGFloat
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: TaskKey(url: url, size: Int(maxPixelSize))) {
            image = await ImageDecoder.shared.image(at: url, maxPixelSize: maxPixelSize)
        }
    }

    private struct TaskKey: Hashable {
        let url: URL
        let size: Int
    }
}

/// Downsampling decoder with a small memory cache.
actor ImageDecoder {
    static let shared = ImageDecoder()

    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 120
    }

    func image(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let bucket = Int(maxPixelSize / 256 + 1) * 256
        let key = "\(url.path)#\(bucket)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: bucket
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }
}
