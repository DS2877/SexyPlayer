import SwiftUI
import UIKit
import ImageIO
import CryptoKit

/// Decoded `UIImage`s kept in memory for instant redisplay while scrolling.
/// Split out of the actor so views can read it synchronously; `NSCache` is
/// itself thread-safe.
final class DecodedImageMemoryCache: @unchecked Sendable {
    static let shared = DecodedImageMemoryCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 140 * 1024 * 1024      // ~140 MB of decoded images
        return c
    }()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: image.estimatedBytes)
    }
}

/// Two-tier image cache: decoded images in memory (`DecodedImageMemoryCache`)
/// and raw bytes on disk (survives relaunch, no re-download). `AsyncImage` does
/// neither, which is why a 40k-poster grid felt slow.
actor ImageCache {
    static let shared = ImageCache()

    private let directory: URL
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private let session: URLSession

    init() {
        let base = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)) ?? URL.temporaryDirectory
        directory = base.appendingPathComponent("PosterImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)

        // Crude cap: if the on-disk cache has grown past ~600 MB, wipe it.
        if let size = try? FileManager.default.allocatedSizeOfDirectory(at: directory),
           size > 600 * 1024 * 1024 {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func image(for url: URL) async -> UIImage? {
        if let hit = DecodedImageMemoryCache.shared.image(for: url) { return hit }

        let key = url.absoluteString
        if let running = inFlight[key] { return await running.value }

        let dir = directory
        let session = self.session
        let task = Task<UIImage?, Never> {
            let fileURL = dir.appendingPathComponent(Self.filename(for: url))
            if let data = try? Data(contentsOf: fileURL), let image = Self.decode(data) {
                return image
            }
            guard let (data, response) = try? await session.data(from: url),
                  let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode),
                  let image = Self.decode(data)
            else { return nil }
            try? data.write(to: fileURL, options: .atomic)
            return image
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { DecodedImageMemoryCache.shared.store(image, for: url) }
        return image
    }

    /// Warm the cache for URLs about to scroll into view, so the first
    /// screenful of a grid is already decoded when it renders.
    nonisolated func prefetch(_ urls: [URL]) {
        for url in urls where DecodedImageMemoryCache.shared.image(for: url) == nil {
            Task.detached(priority: .utility) { _ = await ImageCache.shared.image(for: url) }
        }
    }

    // MARK: - Helpers

    /// Largest edge we ever keep in memory. A tvOS backdrop is ~1920px wide at
    /// 1x; posters need ~480px. Provider artwork is frequently many megapixels —
    /// downsampling on decode is the difference between ~1MB and ~20MB per image.
    private static let maxPixelSize = 1400

    private static func decode(_ data: Data) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: cg)
        }
        // Fallback: plain decode, forced off the main thread.
        guard let image = UIImage(data: data) else { return nil }
        return image.preparingForDisplay() ?? image
    }

    private static func filename(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension UIImage {
    var estimatedBytes: Int {
        guard let cg = cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }
}

private extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> Int {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: keys) else { return 0 }
        var total = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            total += values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
        }
        return total
    }
}

/// Drop-in replacement for `AsyncImage` backed by `ImageCache`. Shows `fallback`
/// while loading and if the load fails.
struct CachedImage<Fallback: View>: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let fallback: () -> Fallback

    @State private var image: UIImage?
    @State private var didFail = false

    init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder fallback: @escaping () -> Fallback) {
        self.url = url
        self.contentMode = contentMode
        self.fallback = fallback
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else if didFail {
                fallback()
            }
        }
        .task(id: url) {
            didFail = false
            guard let url else { image = nil; return }
            if let hit = DecodedImageMemoryCache.shared.image(for: url) {
                image = hit
                return
            }
            image = nil
            let loaded = await ImageCache.shared.image(for: url)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                image = loaded
                didFail = loaded == nil
            }
        }
    }
}

extension CachedImage where Fallback == Color {
    init(url: URL?, contentMode: ContentMode = .fill) {
        self.init(url: url, contentMode: contentMode, fallback: { Color.clear })
    }
}
