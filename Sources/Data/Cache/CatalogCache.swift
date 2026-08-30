import Foundation

/// Persists a normalised `Catalog` per provider as three binary property lists:
///
///   `…-channels`  — decoded on launch to become interactive (~½s)
///   `…-vod`       — movies + series, loaded right after in the background
///   `…-epg`       — the guide (the slowest to decode), loaded last
///
/// So the app is usable almost immediately and the rest streams in.
public actor CatalogCache {

    public struct ChannelsEntry: Sendable {
        public let channels: [Channel]
        public let savedAt: Date
        public var age: TimeInterval { Date().timeIntervalSince(savedAt) }
    }

    private struct ChannelsEnvelope: Codable { let version: Int; let savedAt: Date; let channels: [Channel] }
    private struct VODEnvelope: Codable { let version: Int; let movies: [Movie]; let series: [Series] }
    private struct EPGEnvelope: Codable { let version: Int; let events: [EPGEvent] }

    /// Bump whenever normalization or the model shape changes.
    private static let currentVersion = 6   // 3-file split cache
    private let directory: URL

    private static let encoder: PropertyListEncoder = {
        let e = PropertyListEncoder(); e.outputFormat = .binary; return e
    }()
    private static let decoder = PropertyListDecoder()

    public init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)) ?? URL.temporaryDirectory
        self.directory = base.appendingPathComponent("CatalogCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func safe(_ id: String) -> String {
        id.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
    }
    private func url(_ id: String, _ part: String) -> URL {
        directory.appendingPathComponent("\(safe(id))-\(part).plist")
    }

    // MARK: - Load

    public func loadChannels(providerID: String) -> ChannelsEntry? {
        guard let data = try? Data(contentsOf: url(providerID, "channels")) else { return nil }
        let start = Date()
        guard let env = try? Self.decoder.decode(ChannelsEnvelope.self, from: data), env.version == Self.currentVersion else {
            clear(providerID: providerID); return nil
        }
        AppLog.app.info("Cache channels decoded in \(Int(Date().timeIntervalSince(start) * 1000)) ms.")
        return ChannelsEntry(channels: env.channels, savedAt: env.savedAt)
    }

    public func loadVOD(providerID: String) -> (movies: [Movie], series: [Series]) {
        guard let data = try? Data(contentsOf: url(providerID, "vod")),
              let env = try? Self.decoder.decode(VODEnvelope.self, from: data),
              env.version == Self.currentVersion else { return ([], []) }
        return (env.movies, env.series)
    }

    public func loadEPG(providerID: String) -> [EPGEvent] {
        guard let data = try? Data(contentsOf: url(providerID, "epg")),
              let env = try? Self.decoder.decode(EPGEnvelope.self, from: data),
              env.version == Self.currentVersion else { return [] }
        return env.events
    }

    // MARK: - Save

    public func save(_ catalog: Catalog, providerID: String) {
        let v = Self.currentVersion
        write(ChannelsEnvelope(version: v, savedAt: Date(), channels: catalog.channels), to: url(providerID, "channels"), label: "channels")
        write(VODEnvelope(version: v, movies: catalog.movies, series: catalog.series), to: url(providerID, "vod"), label: "vod")

        let now = Date()
        let lower = now.addingTimeInterval(-2 * 3600)
        let upper = now.addingTimeInterval(4 * 24 * 3600)
        let events = catalog.epg.filter { $0.stop > lower && $0.start < upper }
        write(EPGEnvelope(version: v, events: events), to: url(providerID, "epg"), label: "epg (\(events.count) events)")
    }

    private func write<T: Encodable>(_ value: T, to url: URL, label: String) {
        guard let data = try? Self.encoder.encode(value) else { return }
        do { try data.write(to: url, options: .atomic); AppLog.app.info("Cache \(label) written (\(data.count / 1024) KB).") }
        catch { AppLog.app.notice("Could not write cache \(label).") }
    }

    public func clear(providerID: String) {
        for part in ["channels", "vod", "epg"] { try? FileManager.default.removeItem(at: url(providerID, part)) }
    }

    public func clearAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
