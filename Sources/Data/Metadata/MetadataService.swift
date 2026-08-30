import Foundation

/// TMDB-sourced enrichment for one catalog item. Kept as an overlay looked up by
/// `CatalogID` at display time — never merged into the catalog itself.
public struct EnrichedMetadata: Codable, Sendable, Equatable {
    public let tmdbID: Int          // -1 = we searched and found nothing
    public let posterURL: URL?
    public let backdropURL: URL?
    public let overview: String?
    public let rating: Double?       // 0…10
    public let fetchedAt: Date

    public var matched: Bool { tmdbID > 0 }
}

/// Enriches the catalog from TMDB in the background: deduped, rate-limited,
/// persisted to disk. A card asks for its poster on appear; the result fades in
/// when it arrives. No key configured → does nothing and every caller gets nil.
public actor MetadataService {

    private var byID: [String: EnrichedMetadata] = [:]
    private var inFlight: [String: Task<EnrichedMetadata?, Never>] = [:]
    private var client: TMDBClient?
    private var lastRequestAt = Date.distantPast
    private var dirty = false
    private var saveTask: Task<Void, Never>?

    /// ~8 requests/sec — comfortably inside TMDB's limits.
    private let minInterval: TimeInterval = 0.13
    /// Retry a "no match" after a week in case the title cleaned up.
    private let noMatchRetryAfter: TimeInterval = 7 * 24 * 3600

    private let fileURL: URL

    public init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)) ?? URL.temporaryDirectory
        self.fileURL = base.appendingPathComponent("tmdb-metadata.v1.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: EnrichedMetadata].self, from: data) {
            byID = decoded
        }
    }

    public func setKey(_ key: String?) {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        client = trimmed.isEmpty ? nil : TMDBClient(apiKey: trimmed)
    }

    public var isEnabled: Bool { client != nil }

    /// Cached value if present; otherwise fetch (deduped). Returns nil when no
    /// key is configured or nothing matched.
    public func metadata(for id: CatalogID, title: String, year: Int?, isSeries: Bool) async -> EnrichedMetadata? {
        let key = id.rawValue

        if let existing = byID[key] {
            if existing.matched { return existing }
            if Date().timeIntervalSince(existing.fetchedAt) < noMatchRetryAfter { return nil }
        }
        guard client != nil else { return nil }

        if let running = inFlight[key] { return await running.value }

        let task = Task<EnrichedMetadata?, Never> { [weak self] in
            await self?.fetch(key: key, title: title, year: year, isSeries: isSeries) ?? nil
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    private func fetch(key: String, title: String, year: Int?, isSeries: Bool) async -> EnrichedMetadata? {
        guard let client else { return nil }

        // Space requests out.
        let wait = minInterval - Date().timeIntervalSince(lastRequestAt)
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        lastRequestAt = Date()

        let match: TMDBClient.Match?
        do {
            match = try await client.search(title: title, year: year, isSeries: isSeries)
        } catch {
            return nil   // transient — don't cache a failure, let it retry later
        }

        let record: EnrichedMetadata
        if let match {
            record = EnrichedMetadata(tmdbID: match.tmdbID, posterURL: match.posterURL,
                                      backdropURL: match.backdropURL, overview: match.overview,
                                      rating: match.rating, fetchedAt: Date())
        } else {
            record = EnrichedMetadata(tmdbID: -1, posterURL: nil, backdropURL: nil,
                                      overview: nil, rating: nil, fetchedAt: Date())
        }

        byID[key] = record
        scheduleSave()
        return record.matched ? record : nil
    }

    private func scheduleSave() {
        dirty = true
        guard saveTask == nil else { return }
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            await self?.flush()
        }
    }

    private func flush() {
        saveTask = nil
        guard dirty else { return }
        dirty = false
        if let data = try? JSONEncoder().encode(byID) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public func clear() {
        byID.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }
}
