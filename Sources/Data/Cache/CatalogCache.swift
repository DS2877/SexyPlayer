import Foundation

/// Persists a normalised `Catalog` per provider as JSON in Application Support,
/// so relaunching doesn't re-download and re-parse the whole library.
///
/// Stale-while-revalidate: the app loads this instantly on launch, then
/// refreshes from the provider in the background.
public actor CatalogCache {

    public struct Entry: Sendable {
        public let catalog: Catalog
        public let savedAt: Date
        public var age: TimeInterval { Date().timeIntervalSince(savedAt) }
    }

    private struct Envelope: Codable {
        let version: Int
        let savedAt: Date
        let catalog: Catalog
    }

    /// Bump whenever normalization or the model shape changes, so stale caches
    /// are discarded and the catalog is re-imported once.
    private static let currentVersion = 4   // binary plist; + addedAt, channel numbers
    private let directory: URL

    // Binary property list encodes/decodes a big catalog ~2× faster than JSON
    // and is more compact — matters at 40k+ items.
    private static let encoder: PropertyListEncoder = {
        let e = PropertyListEncoder(); e.outputFormat = .binary; return e
    }()
    private static let decoder = PropertyListDecoder()

    public init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL.temporaryDirectory
        self.directory = base.appendingPathComponent("CatalogCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for providerID: String) -> URL {
        let safe = providerID.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return directory.appendingPathComponent("\(safe).plist")
    }

    public func load(providerID: String) -> Entry? {
        let url = fileURL(for: providerID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let start = Date()
            let envelope = try Self.decoder.decode(Envelope.self, from: data)
            guard envelope.version == Self.currentVersion else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            AppLog.app.info("Catalog cache decoded in \(ms) ms (\(data.count / 1024) KB).")
            return Entry(catalog: envelope.catalog, savedAt: envelope.savedAt)
        } catch {
            AppLog.app.notice("Catalog cache unreadable, discarding.")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    public func save(_ catalog: Catalog, providerID: String) {
        // EPG goes stale fast and is the bulk of the payload — keep only a
        // relevant window so the cache file stays small.
        var trimmed = catalog
        let now = Date()
        let lower = now.addingTimeInterval(-2 * 3600)
        let upper = now.addingTimeInterval(3 * 24 * 3600)
        trimmed.epg = catalog.epg.filter { $0.stop > lower && $0.start < upper }

        let envelope = Envelope(version: Self.currentVersion, savedAt: Date(), catalog: trimmed)
        let start = Date()
        guard let data = try? Self.encoder.encode(envelope) else { return }
        let url = fileURL(for: providerID)
        do {
            try data.write(to: url, options: .atomic)
            AppLog.app.info("Catalog cached in \(Int(Date().timeIntervalSince(start) * 1000)) ms (\(data.count / 1024) KB).")
        } catch {
            AppLog.app.notice("Could not write catalog cache.")
        }
    }

    public func clear(providerID: String) {
        try? FileManager.default.removeItem(at: fileURL(for: providerID))
    }

    public func clearAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
