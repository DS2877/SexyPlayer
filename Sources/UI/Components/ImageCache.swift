import SwiftUI
import UIKit
import CryptoKit

/// Two-tier image cache: decoded `UIImage`s in memory (instant on re-scroll)
/// and raw bytes on disk (survives relaunch, no re-download). `AsyncImage`
/// does neither well, which is why a 40k-poster grid felt slow.
actor ImageCache {
    static let shared = ImageCache()

    private let memory: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 140 * 1024 * 1024      // ~140 MB of decoded images
        return c
    }()
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
        if let size = try? FileManager.default.allocatedSizeOfDirectory(at: directory), size > 600 * 1024 * 1024 {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// Synchronous memory hit only — for `CachedImage` to skip the fade on
    /// something it already has.
    nonisolated func memoryImage(for url: URL) -> UIImage? {
        memory.object(forKey: url.absoluteString as NSString)
    }

    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString
        if let hit = memory.object(forKey: key as NSString) { return hit }
        if let running = inFlight[key] { return await running.value }

        let task = Task<UIImage?, Never> { [directory, session] in
            let fileURL = directory.appendingPathComponent(Self.filename(for: url))

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
        if let image {
            memory.setObject(image, forKey: key as NSString, cost: image.estimatedBytes)
        }
        return image
    }

    // MARK: - Helpers

    private static func decode(_ data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        // Force-decode off the main thread so scrolling doesn't hitch.
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
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let e = enumerator(at: url, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total = 0
        for case let fileURL as URL in e {
            let v = try fileURL.resourceValues(forKeys: keys)
            total += v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0
        }
        return total
    }
}

/// Drop-in replacement for `AsyncImage` that uses `ImageCache`. Shows `fallback`
/// while loading and if the load fails.
struct CachedImage<Fallback: View>: View {
    let url: URL?
    @ViewBuilder var fallback: () -> Fallback

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if didFail {
                fallback()
            }
        }
        .task(id: url) {
            didFail = false
            guard let url else { image = nil; return }
            if let hit = ImageCache.shared.memoryImage(for: url) {
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
    init(url: URL?) {
        self.init(url: url, fallback: { Color.clear })
    }
}
