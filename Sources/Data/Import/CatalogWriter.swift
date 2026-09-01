import Foundation

/// Streams a provider import into `CatalogDatabase`. Each staged slice is
/// normalised and inserted **in small chunks**, so peak memory is one chunk —
/// flat regardless of how large the provider's library is. This is the whole
/// point of the store: the app never holds the catalog in RAM.
public actor CatalogWriter {

    private let database: CatalogDatabase
    private let normalizer: Normalizer
    private let providerID: String
    private let homeRegions: Set<String>

    /// Rows normalised + written this import — reported to `meta` at `finish()`.
    private var channelCount = 0
    private var movieCount = 0
    private var seriesCount = 0
    private var epgCount = 0

    /// VOD is normalised + inserted this many items at a time.
    private static let vodChunk = 2_000
    /// EPG events per insert batch.
    private static let epgChunk = 5_000
    /// Channels per insert batch.
    private static let channelChunk = 5_000

    public init(database: CatalogDatabase, normalizer: Normalizer, providerID: String, homeRegions: Set<String>) {
        self.database = database
        self.normalizer = normalizer
        self.providerID = providerID
        self.homeRegions = homeRegions
    }

    // MARK: - Import lifecycle

    /// Start an import. `fresh` (a cold start / provider switch) wipes the store
    /// first; a refresh updates rows in place so screens never go blank.
    public func begin(fresh: Bool) async throws {
        if fresh { try await database.clearCatalog() }
        try await database.setMeta(CatalogDatabase.MetaKey.providerID, providerID)
        try await database.setMeta(CatalogDatabase.MetaKey.importComplete, "0")
    }

    public func finish() async throws {
        try await database.setMeta(CatalogDatabase.MetaKey.channelCount, String(channelCount))
        try await database.setMeta(CatalogDatabase.MetaKey.movieCount, String(movieCount))
        try await database.setMeta(CatalogDatabase.MetaKey.seriesCount, String(seriesCount))
        try await database.setMeta(CatalogDatabase.MetaKey.epgCount, String(epgCount))
        try await database.setMeta(CatalogDatabase.MetaKey.importedAt, String(Date().timeIntervalSince1970))
        try await database.setMeta(CatalogDatabase.MetaKey.importComplete, "1")
        // `insertChannels` already stamped `region_priority`; nothing to recompute.
        try? await database.optimize()
    }

    // MARK: - Staged ingest

    public func ingest(_ stage: RawStage) async throws {
        switch stage {
        case .channels(let raw):
            try await ingestChannels(raw)
        case .vod(let movies, let shells, let episodes):
            try await ingestVOD(movies: movies, shells: shells, episodes: episodes)
        case .guide(let raw):
            try await ingestGuide(raw)
        }
    }

    private func ingestChannels(_ raw: [RawChannel]) async throws {
        for chunk in raw.chunked(Self.channelChunk) {
            let channels = await normalizer.normalizeChannels(chunk, providerID: providerID)
            try await database.insertChannels(channels, homeRegions: homeRegions)
            channelCount += channels.count
        }
    }

    private func ingestVOD(movies: [RawVODItem], shells: [RawSeriesShell], episodes: [RawSeriesEpisode]) async throws {
        for chunk in movies.chunked(Self.vodChunk) {
            let result = await normalizer.normalizeVOD(movies: chunk, shells: [], episodes: [], providerID: providerID)
            try await database.insertMovies(result.movies)
            movieCount += result.movies.count
        }

        if !shells.isEmpty {
            for chunk in shells.chunked(Self.vodChunk) {
                let result = await normalizer.normalizeVOD(movies: [], shells: chunk, episodes: [], providerID: providerID)
                try await database.insertSeries(result.series)
                seriesCount += result.series.count
            }
        }

        // Episode-name reconstruction (M3U) has to see every row at once to group
        // them — it's not chunkable. Providers that use this path (M3U) have far
        // smaller libraries than the Xtream shell path above.
        if !episodes.isEmpty {
            let result = await normalizer.normalizeVOD(movies: [], shells: [], episodes: episodes, providerID: providerID)
            for chunk in result.series.chunked(500) {
                try await database.insertSeries(chunk)
            }
            seriesCount += result.series.count
        }
    }

    private func ingestGuide(_ raw: [RawEPGEvent]) async throws {
        let window = EPGWindow.current()
        for chunk in raw.chunked(Self.epgChunk) {
            let events = await normalizer.normalizeGuide(chunk)
            try await database.insertEPG(events, window: window)
            epgCount += events.count
        }
    }

    // MARK: - On-demand episodes (Xtream series)

    public func attachSeasons(rawEpisodes: [RawSeriesEpisode], seriesID: CatalogID) async throws -> [Season] {
        let seasons = normalizer.seasons(forEpisodes: rawEpisodes, seriesID: seriesID, providerID: providerID)
        try await database.replaceSeasons(seasons, seriesID: seriesID)
        return seasons
    }
}

// MARK: - Chunking

extension Array {
    /// Split into consecutive sub-arrays of at most `size` elements.
    func chunked(_ size: Int) -> [[Element]] {
        guard size > 0, count > size else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start ..< Swift.min(start + size, count)])
        }
    }
}
