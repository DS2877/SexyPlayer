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
        // Deliberately small — the Apple TV's memory budget is tight and the raw
        // bytes are still on disk, so an eviction costs a ~10 ms re-decode on the
        // next scroll, not a re-download. NSCache also drops everything on a
        // system memory warning.
        c.totalCostLimit = 56 * 1024 * 1024
        c.countLimit = 40
        return c
    }()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: image.estimatedBytes)
    }

    func removeAll() { cache.removeAllObjects() }
}

/// Bounds how many images decode concurrently. A fast scroll or a rebuild storm
/// can otherwise kick off dozens of `CGImageSourceCreateThumbnail` calls at
/// once, each holding a multi-MB uncompressed bitmap — enough to jetsam the app
/// on device. A small permit count keeps the transient decode footprint flat.
actor DecodeLimiter {
    static let shared = DecodeLimiter(permits: 3)

    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(permits: Int) { self.available = permits }

    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            available += 1
        }
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
        config.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: config)

        // Crude cap: if the on-disk cache has grown past ~350 MB, wipe it.
        if let size = try? FileManager.default.allocatedSizeOfDirectory(at: directory),
           size > 350 * 1024 * 1024 {
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
            var bytes = try? Data(contentsOf: fileURL)
            if bytes == nil {
                if let (data, response) = try? await session.data(from: url),
                   let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) {
                    bytes = data
                    try? data.write(to: fileURL, options: .atomic)
                }
            }
            guard let bytes else { return nil }

            // Gate the expensive part — the decode holds a big uncompressed bitmap.
            await DecodeLimiter.shared.acquire()
            let image = Self.decode(bytes)
            await DecodeLimiter.shared.release()
            return image
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { DecodedImageMemoryCache.shared.store(image, for: url) }
        return image
    }

    /// Warm the cache for URLs about to scroll into view. Bounded to a couple of
    /// workers so a big grid doesn't spawn hundreds of concurrent decodes.
    nonisolated func prefetch(_ urls: [URL]) {
        let pending = urls.filter { DecodedImageMemoryCache.shared.image(for: $0) == nil }
        guard !pending.isEmpty else { return }
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                var it = pending.makeIterator()
                let workers = min(2, pending.count)
                for _ in 0 ..< workers {
                    if let u = it.next() { group.addTask { _ = await ImageCache.shared.image(for: u) } }
                }
                while await group.next() != nil {
                    if let u = it.next() { group.addTask { _ = await ImageCache.shared.image(for: u) } }
                }
            }
        }
    }

    /// Drop the in-memory decoded images (e.g. on a memory warning).
    nonisolated func flushMemory() {
        DecodedImageMemoryCache.shared.removeAll()
    }

    // MARK: - Helpers

    /// Largest edge we ever keep in memory. Posters display at ~520 px (2x); the
    /// Home hero is the only full-width image. 900 keeps the hero acceptable at
    /// TV viewing distance while a decoded 2:3 poster is ~4.9 MB (was ~12 MB at
    /// 1400). Provider artwork is frequently many megapixels — downsampling on
    /// decode is the whole point.
    private static let maxPixelSize = 900

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
