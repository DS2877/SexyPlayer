import Foundation

/// `CatalogQuerying` over `CatalogDatabase`. Owns the visibility state
/// (adult / region / home regions / recent channels) and translates it into
/// the `Scope` every query takes.
///
/// An `actor` for its small mutable state; the heavy work runs on the database
/// actor it calls into, which serialises SQLite access.
public actor SQLiteCatalogRepository: CatalogQuerying {

    private let database: CatalogDatabase
    private let searchEngine: SearchEngine

    private var hideAdult = false
    private var regionLimited = false
    private var homeRegions: Set<String> = ["SE"]

    public init(database: CatalogDatabase, searchEngine: SearchEngine = SearchEngine()) {
        self.database = database
        self.searchEngine = searchEngine
    }

    private var scope: CatalogDatabase.Scope {
        CatalogDatabase.Scope(showAdult: !hideAdult, allRegions: !regionLimited)
    }

    /// Run a throwing database read, logging and falling back on failure — a
    /// query hiccup should degrade a screen, never crash it.
    private func read<T>(_ fallback: T, _ body: () async throws -> T) async -> T {
        do { return try await body() }
        catch {
            AppLog.app.error("Catalog query failed: \(String(describing: error))")
            return fallback
        }
    }

    /// `read` for queries that return an optional — nothing found and a query
    /// error both yield `nil`.
    private func readOptional<T>(_ body: () async throws -> T?) async -> T? {
        do { return try await body() }
        catch {
            AppLog.app.error("Catalog query failed: \(String(describing: error))")
            return nil
        }
    }

    // MARK: - Readiness

    public func isReady() async -> Bool {
        await database.importIsComplete()
    }

    // MARK: - Visibility

    public func setHideAdult(_ hide: Bool) async { hideAdult = hide }
    public func setRegionLimit(_ limited: Bool) async { regionLimited = limited }

    public func setHomeRegions(_ regions: Set<String>) async {
        guard regions != homeRegions else { return }
        homeRegions = regions
        try? await database.updateRegionPriorities(homeRegions: regions)
    }

    public func setRecentChannels(_ ids: [CatalogID]) async {
        try? await database.updateRecentChannels(ids)
    }

    // MARK: - Channels

    public func channels(in category: String?, sort: ChannelSort, page: Int, pageSize: Int) async -> [Channel] {
        await read([]) { try await database.channels(category: category, sort: sort, scope, page: page, pageSize: pageSize) }
    }

    public func channelsCount(in category: String?) async -> Int {
        await read(0) { try await database.channelCount(category: category, scope) }
    }

    public func channelTitleAnchors(in category: String?) async -> [BrowseAnchor] {
        await read([]) { Self.anchors(try await database.channelNamesInOrder(category: category, scope)) }
    }

    public func allChannelCategories() async -> [String] {
        await read(["All"]) { try await database.channelCategories() }
    }

    public func channel(id: CatalogID) async -> Channel? {
        await readOptional { try await database.channel(id: id) }
    }

    // MARK: - Movies / series

    public func movies(filter: CatalogFilter, page: Int, pageSize: Int) async -> [Movie] {
        await read([]) { try await database.movies(filter, scope, page: page, pageSize: pageSize) }
    }

    public func series(filter: CatalogFilter, page: Int, pageSize: Int) async -> [Series] {
        await read([]) { try await database.series(filter, scope, page: page, pageSize: pageSize) }
    }

    public func moviesCount(filter: CatalogFilter) async -> Int {
        await read(0) { try await database.movieCount(filter, scope) }
    }

    public func seriesCount(filter: CatalogFilter) async -> Int {
        await read(0) { try await database.seriesCount(filter, scope) }
    }

    public func movieTitleAnchors(filter: CatalogFilter) async -> [BrowseAnchor] {
        await read([]) { Self.anchors(try await database.movieTitlesInOrder(filter, scope)) }
    }

    public func seriesTitleAnchors(filter: CatalogFilter) async -> [BrowseAnchor] {
        await read([]) { Self.anchors(try await database.seriesTitlesInOrder(filter, scope)) }
    }

    public func movie(id: CatalogID) async -> Movie? {
        await readOptional { try await database.movie(id: id) }
    }

    public func series(id: CatalogID) async -> Series? {
        await readOptional { try await database.series(id: id) }
    }

    public func attachSeasons(_ seasons: [Season], toSeriesID id: CatalogID) async {
        try? await database.replaceSeasons(seasons, seriesID: id)
    }

    public func hasEpisodes(seriesID: CatalogID) async -> Bool {
        await read(false) { try await database.hasEpisodes(seriesID: seriesID) }
    }

    // MARK: - Facets

    public func availableGenres() async -> [Genre] {
        await read([]) { try await database.presentGenres() }
    }

    public func availableAudioLanguages() async -> [Language] {
        await read([]) { try await database.presentLanguages(subtitles: false) }
    }

    public func availableSubtitleLanguages() async -> [Language] {
        await read([]) { try await database.presentLanguages(subtitles: true) }
    }

    // MARK: - Batch id lookups

    public func movies(ids: [CatalogID]) async -> [Movie] {
        await read([]) { try await database.moviesByID(ids) }
    }

    public func series(ids: [CatalogID]) async -> [Series] {
        await read([]) { try await database.seriesWithSeasons(ids: ids) }
    }

    public func channels(ids: [CatalogID]) async -> [Channel] {
        await read([]) { try await database.channelsByID(ids) }
    }

    public func episode(id: CatalogID) async -> Episode? {
        await readOptional { try await database.episode(id: id) }
    }

    // MARK: - EPG

    public func epgEvents(forEPGID epgID: String, in window: DateInterval) async -> [EPGEvent] {
        await read([]) { try await database.epgEvents(epgID: epgID, in: window) }
    }

    public func nowPlaying(forEPGID epgID: String, at date: Date) async -> EPGEvent? {
        await readOptional { try await database.nowPlaying(epgID: epgID, at: date) }
    }

    public func epgIndex(forEPGIDs epgIDs: [String], in window: DateInterval) async -> [String: [EPGEvent]] {
        await read([:]) { try await database.epgIndex(epgIDs: epgIDs, in: window) }
    }

    public func guideChannels(limit: Int) async -> [Channel] {
        await read([]) { try await database.guideChannels(limit: limit, scope) }
    }

    // MARK: - Home / discovery

    public func recentlyAdded(limit: Int) async -> [SearchResult.Item] {
        await read([]) {
            let movies = try await database.recentlyAddedMovies(limit: limit, scope).map { SearchResult.Item.movie($0) }
            let series = try await database.recentlyAddedSeries(limit: limit, scope).map { SearchResult.Item.series($0) }
            return Array((movies + series).prefix(limit))
        }
    }

    public func newestMovies(limit: Int) async -> [Movie] {
        await read([]) { try await database.recentlyAddedMovies(limit: limit, scope) }
    }

    public func newestSeries(limit: Int) async -> [Series] {
        await read([]) { try await database.recentlyAddedSeries(limit: limit, scope) }
    }

    public func topGenres(limit: Int) async -> [Genre] {
        await read([]) { Array(try await database.genreCounts(scope).prefix(limit).map(\.genre)) }
    }

    public func moviesInGenre(_ genre: Genre, limit: Int) async -> [Movie] {
        await read([]) { try await database.moviesInGenre(genre, scope, limit: limit) }
    }

    public func seriesInGenre(_ genre: Genre, limit: Int) async -> [Series] {
        await read([]) { try await database.seriesInGenre(genre, scope, limit: limit) }
    }

    public func moviesInAudioLanguages(_ languages: [Language], limit: Int) async -> [Movie] {
        await read([]) { try await database.moviesInAudioLanguages(languages, scope, limit: limit) }
    }

    public func moviesInSubtitleLanguage(_ language: Language, limit: Int) async -> [Movie] {
        await read([]) { try await database.moviesInSubtitleLanguage(language, scope, limit: limit) }
    }

    public func similarMovies(to id: CatalogID, genres: [Genre], limit: Int) async -> [Movie] {
        await read([]) { try await database.similarMovies(to: id, genres: genres, scope, limit: limit) }
    }

    public func similarSeries(to id: CatalogID, genres: [Genre], limit: Int) async -> [Series] {
        await read([]) { try await database.similarSeries(to: id, genres: genres, scope, limit: limit) }
    }

    public func resumePoints(progress: [WatchProgress], limit: Int) async -> [ResumePoint] {
        await read([]) {
            let movieIDs = progress.filter { $0.kind == .movie }.map(\.itemID)
            let episodeIDs = progress.filter { $0.kind == .series }.map(\.itemID)

            let movies = try await database.moviesByID(movieIDs)
            let episodes = try await database.episodesByID(episodeIDs)
            let seriesIDs = Array(Set(episodes.map(\.seriesID)))
            let series = try await database.seriesWithSeasons(ids: seriesIDs)

            let miniCatalog = Catalog(channels: [], movies: movies, series: series)
            return UpNext.resumePoints(catalog: miniCatalog, progress: progress, limit: limit)
        }
    }

    // MARK: - Search

    public func search(_ intent: SearchIntent, limit: Int) async -> [SearchResult] {
        await read([]) {
            let filter = CatalogFilter(intent: intent)
            let wantMovies = intent.kinds.isEmpty || intent.kinds.contains(.movie)
            let wantSeries = intent.kinds.isEmpty || intent.kinds.contains(.series)
            let wantChannels = intent.kinds.contains(.liveChannel)

            let candidateCap = Swift.max(limit * 4, 400)
            let movies = wantMovies ? try await database.movieCandidates(filter, scope, limit: candidateCap) : []
            let series = wantSeries ? try await database.seriesCandidates(filter, scope, limit: candidateCap) : []
            let channels = wantChannels
                ? try await database.channelCandidates(text: intent.freeText, scope, limit: candidateCap)
                : []

            let candidates = Catalog(channels: channels, movies: movies, series: series)
            return searchEngine.search(intent, in: candidates, limit: limit)
        }
    }

    public func searchVocabulary() async -> SearchVocabulary {
        await read(SearchVocabulary()) {
            let genres = try await database.presentGenres()
            let audio = try await database.presentLanguages(subtitles: false)
            let subs = try await database.presentLanguages(subtitles: true)
            let movieCount = try await database.movieCount(.none, .unfiltered)
            let seriesCount = try await database.seriesCount(.none, .unfiltered)
            let channelCount = try await database.channelCount(category: nil, .unfiltered)
            return SearchVocabulary(
                genres: genres.isEmpty ? Genre.allCases : genres.sorted { $0.rawValue < $1.rawValue },
                audioLanguages: audio,
                subtitleLanguages: subs,
                hasMovies: movieCount > 0,
                hasSeries: seriesCount > 0,
                hasLiveTV: channelCount > 0
            )
        }
    }

    // MARK: - Metadata warm-up

    public func artworkSeeds(movieLimit: Int, seriesLimit: Int) async -> [ArtworkSeed] {
        await read([]) { try await database.artworkSeeds(movieLimit: movieLimit, seriesLimit: seriesLimit) }
    }

    // MARK: - A–Z anchors (shared shape with the in-memory repository)

    static func anchors(_ titlesInOrder: [String]) -> [BrowseAnchor] {
        var result: [BrowseAnchor] = []
        var seen = Set<String>()
        for (index, title) in titlesInOrder.enumerated() {
            let letter = anchorLetter(for: title)
            if seen.insert(letter).inserted {
                result.append(BrowseAnchor(letter: letter, index: index))
            }
        }
        return result
    }

    private static func anchorLetter(for title: String) -> String {
        let stripped = title.folding(options: .diacriticInsensitive, locale: nil)
            .drop { !$0.isLetter && !$0.isNumber }
        guard let first = stripped.first else { return "#" }
        return first.isNumber ? "#" : first.uppercased()
    }
}
