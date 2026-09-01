import Foundation

/// The catalog store. One SQLite connection, owned by this `actor` and never
/// handed out, so all access is serialised without locks. `SQLiteCatalogRepository`
/// reads through it; `CatalogWriter` streams an import into it.
///
/// Every read takes an explicit `CatalogScope` (adult / region visibility) rather
/// than holding that state here — the repository layer owns it.
public actor CatalogDatabase {

    private let connection: SQLiteConnection

    /// Adult / region visibility applied to a query as `WHERE` clauses.
    public struct Scope: Sendable, Equatable {
        public var showAdult: Bool
        public var allRegions: Bool
        public init(showAdult: Bool = true, allRegions: Bool = true) {
            self.showAdult = showAdult
            self.allRegions = allRegions
        }
        public static let unfiltered = Scope(showAdult: true, allRegions: true)
    }

    // MARK: - Lifecycle

    public init(path: URL) throws {
        connection = try SQLiteConnection(path: path.path)
        try CatalogSchema.migrate(connection)
    }

    /// Open (creating if needed) the catalog store in Application Support.
    public static func open() throws -> CatalogDatabase {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let directory = base.appendingPathComponent("AeriaCatalog", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try CatalogDatabase(path: directory.appendingPathComponent("catalog.sqlite3"))
    }

    // MARK: - Meta

    public func metaValue(_ key: String) throws -> String? {
        try connection.queryOne("SELECT value FROM meta WHERE key = ?", [.text(key)]) { $0.stringOrNil(0) } ?? nil
    }

    public func setMeta(_ key: String, _ value: String?) throws {
        try connection.run(
            "INSERT INTO meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            [.text(key), SQLiteValue(value)]
        )
    }

    private func rawMeta(_ key: String) -> String? {
        guard let outer = try? metaValue(key) else { return nil }
        return outer
    }

    public func intMeta(_ key: String) -> Int {
        guard let text = rawMeta(key), let value = Int(text) else { return 0 }
        return value
    }

    /// A completed import exists for this provider.
    public func isReady(providerID: String) -> Bool {
        rawMeta(MetaKey.providerID) == providerID && intMeta(MetaKey.importComplete) == 1
    }

    /// A completed import exists for whichever provider was last imported.
    public func importIsComplete() -> Bool {
        intMeta(MetaKey.importComplete) == 1 && rawMeta(MetaKey.providerID) != nil
    }

    public func loadedProviderID() -> String? {
        rawMeta(MetaKey.providerID)
    }

    public enum MetaKey {
        public static let providerID = "provider_id"
        public static let importComplete = "import_complete"
        public static let importedAt = "imported_at"
        public static let channelCount = "channel_count"
        public static let movieCount = "movie_count"
        public static let seriesCount = "series_count"
        public static let epgCount = "epg_count"
    }

    // MARK: - Column lists (SELECT order must match the decoders below)

    private static let movieColumns = """
    id, title, year, duration_min, audio_langs, sub_langs, genres, quality, \
    country_code, poster_url, backdrop_url, synopsis, cast_list, directors, stream_url, added_at, is_adult
    """

    private static let seriesColumns = """
    id, title, year, audio_langs, sub_langs, genres, quality, country_code, \
    poster_url, backdrop_url, synopsis, provider_key, added_at, is_adult
    """

    private static let channelColumns = """
    id, name, category, logo_url, country_code, audio_langs, sub_langs, quality, \
    stream_url, epg_id, sort_index, is_adult
    """

    private static let episodeColumns = """
    id, series_id, season, episode, title, overview, duration_min, still_url, stream_url
    """

    private static let epgColumns = "channel_epg_id, title, subtitle, description, start_at, stop_at, category"

    // MARK: - Row decoders

    private static func decodeMovie(_ row: SQLiteRow) -> Movie {
        Movie(
            id: CatalogID(rawValue: row.string(0)),
            title: row.string(1),
            year: row.intOrNil(2),
            genres: CatalogValues.decodeGenres(row.string(6)),
            durationMinutes: row.intOrNil(3),
            audioLanguages: CatalogValues.decodeLanguages(row.string(4)),
            subtitleLanguages: CatalogValues.decodeLanguages(row.string(5)),
            quality: CatalogValues.decodeQuality(row.string(7)),
            countryCode: row.stringOrNil(8),
            posterURL: row.url(9),
            backdropURL: row.url(10),
            synopsis: row.stringOrNil(11),
            cast: CatalogValues.decodeList(row.string(12)),
            directors: CatalogValues.decodeList(row.string(13)),
            streamURL: row.url(14) ?? Normalizer.placeholderURL,
            addedAt: row.date(15),
            isAdult: row.bool(16)
        )
    }

    private static func decodeSeries(_ row: SQLiteRow, seasons: [Season]) -> Series {
        Series(
            id: CatalogID(rawValue: row.string(0)),
            title: row.string(1),
            year: row.intOrNil(2),
            genres: CatalogValues.decodeGenres(row.string(5)),
            audioLanguages: CatalogValues.decodeLanguages(row.string(3)),
            subtitleLanguages: CatalogValues.decodeLanguages(row.string(4)),
            quality: CatalogValues.decodeQuality(row.string(6)),
            countryCode: row.stringOrNil(7),
            posterURL: row.url(8),
            backdropURL: row.url(9),
            synopsis: row.stringOrNil(10),
            seasons: seasons,
            providerSeriesKey: row.stringOrNil(11),
            addedAt: row.date(12),
            isAdult: row.bool(13)
        )
    }

    private static func decodeChannel(_ row: SQLiteRow) -> Channel {
        Channel(
            id: CatalogID(rawValue: row.string(0)),
            name: row.string(1),
            category: row.string(2),
            logoURL: row.url(3),
            countryCode: row.stringOrNil(4),
            audioLanguages: CatalogValues.decodeLanguages(row.string(5)),
            subtitleLanguages: CatalogValues.decodeLanguages(row.string(6)),
            quality: CatalogValues.decodeQuality(row.string(7)),
            streamURL: row.url(8) ?? Normalizer.placeholderURL,
            epgID: row.stringOrNil(9),
            sortIndex: row.int(10),
            isAdult: row.bool(11)
        )
    }

    private static func decodeEpisode(_ row: SQLiteRow) -> Episode {
        Episode(
            id: CatalogID(rawValue: row.string(0)),
            seriesID: CatalogID(rawValue: row.string(1)),
            seasonNumber: row.int(2),
            episodeNumber: row.int(3),
            title: row.string(4),
            overview: row.stringOrNil(5),
            durationMinutes: row.intOrNil(6),
            stillURL: row.url(7),
            streamURL: row.url(8) ?? Normalizer.placeholderURL
        )
    }

    private static func decodeEPG(_ row: SQLiteRow) -> EPGEvent {
        EPGEvent(
            channelEPGID: row.string(0),
            title: row.string(1),
            subtitle: row.stringOrNil(2),
            description: row.stringOrNil(3),
            start: Date(timeIntervalSince1970: row.double(4)),
            stop: Date(timeIntervalSince1970: row.double(5)),
            category: row.stringOrNil(6)
        )
    }

    // MARK: - Scope predicate

    /// `(clause, params)` for the adult / region gate, always safe to `AND` in.
    private func scopeClause(_ scope: Scope) -> (String, [SQLiteValue]) {
        ("(? OR is_adult = 0) AND (? OR is_relevant = 1)",
         [SQLiteValue(scope.showAdult), SQLiteValue(scope.allRegions)])
    }

    // MARK: - Facets

    public func channelCategories() throws -> [String] {
        let names = try connection.query("SELECT DISTINCT category FROM channel ORDER BY category") { $0.string(0) }
        return ["All"] + names
    }

    public func presentGenres() throws -> [Genre] {
        let raw = Set(try connection.query("SELECT DISTINCT genre FROM movie_genre") { $0.string(0) }
                      + connection.query("SELECT DISTINCT genre FROM series_genre") { $0.string(0) })
        return Genre.allCases.filter { raw.contains($0.rawValue) }
    }

    public func presentLanguages(subtitles: Bool) throws -> [Language] {
        let column = subtitles ? "sub_langs" : "audio_langs"
        let rows = try connection.query(
            "SELECT \(column) FROM movie WHERE \(column) <> '' " +
            "UNION SELECT \(column) FROM series WHERE \(column) <> ''"
        ) { $0.string(0) }
        var codes = Set<String>()
        for wrapped in rows { for part in wrapped.split(separator: ",") { codes.insert(String(part)) } }
        return codes.compactMap { Language(code: $0) }.sorted()
    }

    // MARK: - Counts

    public func movieCount(_ filter: CatalogFilter, _ scope: Scope) throws -> Int {
        let (where_, params) = movieWhere(filter, scope)
        return try connection.scalarInt("SELECT count(*) FROM movie WHERE \(where_)", params)
    }

    public func seriesCount(_ filter: CatalogFilter, _ scope: Scope) throws -> Int {
        let (where_, params) = seriesWhere(filter, scope)
        return try connection.scalarInt("SELECT count(*) FROM series WHERE \(where_)", params)
    }

    public func channelCount(category: String?, _ scope: Scope) throws -> Int {
        let (where_, params) = channelWhere(category: category, scope)
        return try connection.scalarInt("SELECT count(*) FROM channel WHERE \(where_)", params)
    }

    // MARK: - Paged lists

    public func movies(_ filter: CatalogFilter, _ scope: Scope, page: Int, pageSize: Int) throws -> [Movie] {
        let (where_, params) = movieWhere(filter, scope)
        let sql = "SELECT \(Self.movieColumns) FROM movie WHERE \(where_) " +
                  "ORDER BY \(Self.orderClause(filter.sort)) LIMIT ? OFFSET ?"
        return try connection.query(sql, params + [.integer(Int64(pageSize)), .integer(Int64(page * pageSize))], Self.decodeMovie)
    }

    public func series(_ filter: CatalogFilter, _ scope: Scope, page: Int, pageSize: Int) throws -> [Series] {
        let (where_, params) = seriesWhere(filter, scope)
        let sql = "SELECT \(Self.seriesColumns) FROM series WHERE \(where_) " +
                  "ORDER BY \(Self.orderClause(filter.sort)) LIMIT ? OFFSET ?"
        return try connection.query(sql, params + [.integer(Int64(pageSize)), .integer(Int64(page * pageSize))]) {
            Self.decodeSeries($0, seasons: [])
        }
    }

    public func channels(category: String?, sort: ChannelSort, _ scope: Scope, page: Int, pageSize: Int) throws -> [Channel] {
        let (where_, params) = channelWhere(category: category, scope)
        let order: String
        switch sort {
        case .number:  order = "(recent_rank IS NULL), recent_rank, region_priority, sort_index, name_fold"
        case .nameAsc: order = "name_fold, sort_index"
        }
        let sql = "SELECT \(Self.channelColumns) FROM channel WHERE \(where_) ORDER BY \(order) LIMIT ? OFFSET ?"
        return try connection.query(sql, params + [.integer(Int64(pageSize)), .integer(Int64(page * pageSize))], Self.decodeChannel)
    }

    // MARK: - Ordered title columns (for the A–Z rails)

    public func movieTitlesInOrder(_ filter: CatalogFilter, _ scope: Scope) throws -> [String] {
        let (where_, params) = movieWhere(filter, scope)
        return try connection.query(
            "SELECT title FROM movie WHERE \(where_) ORDER BY \(Self.orderClause(filter.sort))", params
        ) { $0.string(0) }
    }

    public func seriesTitlesInOrder(_ filter: CatalogFilter, _ scope: Scope) throws -> [String] {
        let (where_, params) = seriesWhere(filter, scope)
        return try connection.query(
            "SELECT title FROM series WHERE \(where_) ORDER BY \(Self.orderClause(filter.sort))", params
        ) { $0.string(0) }
    }

    public func channelNamesInOrder(category: String?, _ scope: Scope) throws -> [String] {
        let (where_, params) = channelWhere(category: category, scope)
        return try connection.query(
            "SELECT name FROM channel WHERE \(where_) ORDER BY name_fold, sort_index", params
        ) { $0.string(0) }
    }

    // MARK: - By id

    public func movie(id: CatalogID) throws -> Movie? {
        try connection.queryOne("SELECT \(Self.movieColumns) FROM movie WHERE id = ?", [.text(id.rawValue)], Self.decodeMovie)
    }

    public func channel(id: CatalogID) throws -> Channel? {
        try connection.queryOne("SELECT \(Self.channelColumns) FROM channel WHERE id = ?", [.text(id.rawValue)], Self.decodeChannel)
    }

    public func series(id: CatalogID) throws -> Series? {
        guard var show = try connection.queryOne(
            "SELECT \(Self.seriesColumns) FROM series WHERE id = ?", [.text(id.rawValue)]
        ) { Self.decodeSeries($0, seasons: []) } else { return nil }
        show.seasons = try seasons(seriesID: id)
        return show
    }

    public func moviesByID(_ ids: [CatalogID]) throws -> [Movie] {
        try fetchByIDs(ids, table: "movie", columns: Self.movieColumns, decode: Self.decodeMovie)
    }

    public func channelsByID(_ ids: [CatalogID]) throws -> [Channel] {
        try fetchByIDs(ids, table: "channel", columns: Self.channelColumns, decode: Self.decodeChannel)
    }

    public func seriesByID(_ ids: [CatalogID]) throws -> [Series] {
        try fetchByIDs(ids, table: "series", columns: Self.seriesColumns) { Self.decodeSeries($0, seasons: []) }
    }

    private func fetchByIDs<T>(_ ids: [CatalogID], table: String, columns: String, decode: (SQLiteRow) -> T) throws -> [T] {
        guard !ids.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        return try connection.query(
            "SELECT \(columns) FROM \(table) WHERE id IN (\(placeholders))",
            ids.map { SQLiteValue.text($0.rawValue) }, decode
        )
    }

    // MARK: - Seasons / episodes

    public func seasons(seriesID: CatalogID) throws -> [Season] {
        let episodes = try connection.query(
            "SELECT \(Self.episodeColumns) FROM episode WHERE series_id = ? ORDER BY season, episode",
            [.text(seriesID.rawValue)], Self.decodeEpisode
        )
        let bySeason = Dictionary(grouping: episodes, by: { $0.seasonNumber })
        return bySeason.keys.sorted().map { number in
            Season(seriesID: seriesID, number: number, episodes: bySeason[number] ?? [])
        }
    }

    public func episode(id: CatalogID) throws -> Episode? {
        try connection.queryOne(
            "SELECT \(Self.episodeColumns) FROM episode WHERE id = ?", [.text(id.rawValue)], Self.decodeEpisode
        )
    }

    public func episodesByID(_ ids: [CatalogID]) throws -> [Episode] {
        try fetchByIDs(ids, table: "episode", columns: Self.episodeColumns, decode: Self.decodeEpisode)
    }

    /// Series for the given ids, each with its full season / episode tree.
    public func seriesWithSeasons(ids: [CatalogID]) throws -> [Series] {
        try seriesByID(ids).map { shell in
            var full = shell
            full.seasons = (try? seasons(seriesID: shell.id)) ?? []
            return full
        }
    }

    public func hasEpisodes(seriesID: CatalogID) throws -> Bool {
        try connection.scalarInt("SELECT count(*) FROM episode WHERE series_id = ? LIMIT 1", [.text(seriesID.rawValue)]) > 0
    }

    // MARK: - Recently added

    public func recentlyAddedMovies(limit: Int, _ scope: Scope) throws -> [Movie] {
        let (clause, params) = scopeClause(scope)
        return try connection.query(
            "SELECT \(Self.movieColumns) FROM movie WHERE \(clause) ORDER BY (added_at IS NULL), added_at DESC LIMIT ?",
            params + [.integer(Int64(limit))], Self.decodeMovie
        )
    }

    public func recentlyAddedSeries(limit: Int, _ scope: Scope) throws -> [Series] {
        let (clause, params) = scopeClause(scope)
        return try connection.query(
            "SELECT \(Self.seriesColumns) FROM series WHERE \(clause) ORDER BY (added_at IS NULL), added_at DESC LIMIT ?",
            params + [.integer(Int64(limit))]
        ) { Self.decodeSeries($0, seasons: []) }
    }

    // MARK: - Genre shelves (Home)

    /// Genres present in the library with their combined movie + series count,
    /// most first.
    public func genreCounts(_ scope: Scope) throws -> [(genre: Genre, count: Int)] {
        let (clause, params) = scopeClause(scope)
        let rows = try connection.query("""
        SELECT genre, sum(n) AS total FROM (
            SELECT g.genre AS genre, count(*) AS n FROM movie_genre g
                JOIN movie m ON m.id = g.movie_id WHERE \(clause) GROUP BY g.genre
            UNION ALL
            SELECT g.genre AS genre, count(*) AS n FROM series_genre g
                JOIN series s ON s.id = g.series_id WHERE \(clause) GROUP BY g.genre
        ) GROUP BY genre ORDER BY total DESC
        """, params + params) { (genre: $0.string(0), count: $0.int(1)) }
        return rows.compactMap { row in
            Genre(rawValue: row.genre).map { (genre: $0, count: row.count) }
        }
    }

    public func moviesInGenre(_ genre: Genre, _ scope: Scope, limit: Int) throws -> [Movie] {
        let (clause, params) = scopeClause(scope)
        return try connection.query("""
        SELECT \(Self.movieColumns) FROM movie
        WHERE \(clause) AND id IN (SELECT movie_id FROM movie_genre WHERE genre = ?)
        ORDER BY (added_at IS NULL), added_at DESC LIMIT ?
        """, params + [.text(genre.rawValue), .integer(Int64(limit))], Self.decodeMovie)
    }

    public func seriesInGenre(_ genre: Genre, _ scope: Scope, limit: Int) throws -> [Series] {
        let (clause, params) = scopeClause(scope)
        return try connection.query("""
        SELECT \(Self.seriesColumns) FROM series
        WHERE \(clause) AND id IN (SELECT series_id FROM series_genre WHERE genre = ?)
        ORDER BY (added_at IS NULL), added_at DESC LIMIT ?
        """, params + [.text(genre.rawValue), .integer(Int64(limit))]) { Self.decodeSeries($0, seasons: []) }
    }

    /// Movies / series that carry one of `languages` in their audio track.
    public func moviesInAudioLanguages(_ languages: [Language], _ scope: Scope, limit: Int) throws -> [Movie] {
        guard !languages.isEmpty else { return [] }
        let (clause, params) = scopeClause(scope)
        let langClause = languages.map { _ in "instr(audio_langs, ?) > 0" }.joined(separator: " OR ")
        return try connection.query(
            "SELECT \(Self.movieColumns) FROM movie WHERE \(clause) AND (\(langClause)) " +
            "ORDER BY (added_at IS NULL), added_at DESC LIMIT ?",
            params + languages.map { SQLiteValue.text(CatalogValues.needle($0)) } + [.integer(Int64(limit))],
            Self.decodeMovie
        )
    }

    public func moviesInSubtitleLanguage(_ language: Language, _ scope: Scope, limit: Int) throws -> [Movie] {
        let (clause, params) = scopeClause(scope)
        return try connection.query(
            "SELECT \(Self.movieColumns) FROM movie WHERE \(clause) AND instr(sub_langs, ?) > 0 " +
            "ORDER BY (added_at IS NULL), added_at DESC LIMIT ?",
            params + [.text(CatalogValues.needle(language)), .integer(Int64(limit))], Self.decodeMovie
        )
    }

    // MARK: - Guide

    /// The channels that carry an EPG id, in "for you" order, capped.
    public func guideChannels(limit: Int, _ scope: Scope) throws -> [Channel] {
        let (clause, params) = scopeClause(scope)
        return try connection.query(
            "SELECT \(Self.channelColumns) FROM channel WHERE \(clause) AND epg_id IS NOT NULL AND epg_id <> '' " +
            "ORDER BY (recent_rank IS NULL), recent_rank, region_priority, sort_index, name_fold LIMIT ?",
            params + [.integer(Int64(limit))], Self.decodeChannel
        )
    }

    // MARK: - Search candidates (ranking stays in SearchEngine)

    public func movieCandidates(_ filter: CatalogFilter, _ scope: Scope, limit: Int) throws -> [Movie] {
        let (where_, params) = movieWhere(filter, scope)
        return try connection.query(
            "SELECT \(Self.movieColumns) FROM movie WHERE \(where_) LIMIT ?",
            params + [.integer(Int64(limit))], Self.decodeMovie
        )
    }

    public func seriesCandidates(_ filter: CatalogFilter, _ scope: Scope, limit: Int) throws -> [Series] {
        let (where_, params) = seriesWhere(filter, scope)
        return try connection.query(
            "SELECT \(Self.seriesColumns) FROM series WHERE \(where_) LIMIT ?",
            params + [.integer(Int64(limit))]
        ) { Self.decodeSeries($0, seasons: []) }
    }

    public func channelCandidates(text: String, _ scope: Scope, limit: Int) throws -> [Channel] {
        let (clause, params) = scopeClause(scope)
        let needle = text.foldedForSearch()
        let textClause = needle.isEmpty ? "" : " AND instr(name_fold, ?) > 0"
        let textParams: [SQLiteValue] = needle.isEmpty ? [] : [.text(needle)]
        return try connection.query(
            "SELECT \(Self.channelColumns) FROM channel WHERE \(clause)\(textClause) LIMIT ?",
            params + textParams + [.integer(Int64(limit))], Self.decodeChannel
        )
    }

    // MARK: - "More like this"

    public func similarMovies(to id: CatalogID, genres: [Genre], _ scope: Scope, limit: Int) throws -> [Movie] {
        guard !genres.isEmpty else { return [] }
        let (clause, params) = scopeClause(scope)
        let genrePlaceholders = Array(repeating: "?", count: genres.count).joined(separator: ",")
        let sql = """
        SELECT \(Self.movieColumns), \
        (SELECT count(*) FROM movie_genre g WHERE g.movie_id = movie.id AND g.genre IN (\(genrePlaceholders))) AS shared
        FROM movie WHERE \(clause) AND id <> ? AND shared > 0
        ORDER BY shared DESC, (added_at IS NULL), added_at DESC LIMIT ?
        """
        let args = params + genres.map { SQLiteValue.text($0.rawValue) } + [.text(id.rawValue), .integer(Int64(limit))]
        return try connection.query(sql, args, Self.decodeMovie)
    }

    public func similarSeries(to id: CatalogID, genres: [Genre], _ scope: Scope, limit: Int) throws -> [Series] {
        guard !genres.isEmpty else { return [] }
        let (clause, params) = scopeClause(scope)
        let genrePlaceholders = Array(repeating: "?", count: genres.count).joined(separator: ",")
        let sql = """
        SELECT \(Self.seriesColumns), \
        (SELECT count(*) FROM series_genre g WHERE g.series_id = series.id AND g.genre IN (\(genrePlaceholders))) AS shared
        FROM series WHERE \(clause) AND id <> ? AND shared > 0
        ORDER BY shared DESC, (added_at IS NULL), added_at DESC LIMIT ?
        """
        let args = params + genres.map { SQLiteValue.text($0.rawValue) } + [.text(id.rawValue), .integer(Int64(limit))]
        return try connection.query(sql, args) { Self.decodeSeries($0, seasons: []) }
    }

    // MARK: - Artwork seeds (newest first)

    public func artworkSeeds(movieLimit: Int, seriesLimit: Int) throws -> [ArtworkSeed] {
        let movies = try connection.query(
            "SELECT id, title, year FROM movie ORDER BY (added_at IS NULL), added_at DESC LIMIT ?",
            [.integer(Int64(movieLimit))]
        ) { ArtworkSeed(id: CatalogID(rawValue: $0.string(0)), title: $0.string(1), year: $0.intOrNil(2), isSeries: false) }
        let series = try connection.query(
            "SELECT id, title, year FROM series ORDER BY (added_at IS NULL), added_at DESC LIMIT ?",
            [.integer(Int64(seriesLimit))]
        ) { ArtworkSeed(id: CatalogID(rawValue: $0.string(0)), title: $0.string(1), year: $0.intOrNil(2), isSeries: true) }
        return movies + series
    }

    // MARK: - EPG

    public func epgEvents(epgID: String, in window: DateInterval) throws -> [EPGEvent] {
        try connection.query(
            "SELECT \(Self.epgColumns) FROM epg_event WHERE channel_epg_id = ? AND stop_at > ? AND start_at < ? ORDER BY start_at",
            [.text(epgID), .real(window.start.timeIntervalSince1970), .real(window.end.timeIntervalSince1970)],
            Self.decodeEPG
        )
    }

    public func nowPlaying(epgID: String, at date: Date) throws -> EPGEvent? {
        let t = date.timeIntervalSince1970
        return try connection.queryOne(
            "SELECT \(Self.epgColumns) FROM epg_event WHERE channel_epg_id = ? AND start_at <= ? AND stop_at > ? ORDER BY start_at DESC LIMIT 1",
            [.text(epgID), .real(t), .real(t)], Self.decodeEPG
        )
    }

    /// Every event for the given EPG ids inside the window, grouped by id.
    public func epgIndex(epgIDs: [String], in window: DateInterval) throws -> [String: [EPGEvent]] {
        guard !epgIDs.isEmpty else { return [:] }
        let placeholders = Array(repeating: "?", count: epgIDs.count).joined(separator: ",")
        let rows = try connection.query(
            "SELECT \(Self.epgColumns) FROM epg_event WHERE channel_epg_id IN (\(placeholders)) " +
            "AND stop_at > ? AND start_at < ? ORDER BY channel_epg_id, start_at",
            epgIDs.map { SQLiteValue.text($0) } +
            [.real(window.start.timeIntervalSince1970), .real(window.end.timeIntervalSince1970)],
            Self.decodeEPG
        )
        return Dictionary(grouping: rows, by: { $0.channelEPGID })
    }

    // MARK: - WHERE builders

    private func movieWhere(_ filter: CatalogFilter, _ scope: Scope) -> (String, [SQLiteValue]) {
        var clauses = ["(? OR is_adult = 0)", "(? OR is_relevant = 1)"]
        var params: [SQLiteValue] = [SQLiteValue(scope.showAdult), SQLiteValue(scope.allRegions)]
        appendCommon(to: &clauses, params: &params, filter: filter, genreTable: "movie_genre", idColumn: "movie_id", hasDuration: true)
        return (clauses.joined(separator: " AND "), params)
    }

    private func seriesWhere(_ filter: CatalogFilter, _ scope: Scope) -> (String, [SQLiteValue]) {
        var clauses = ["(? OR is_adult = 0)", "(? OR is_relevant = 1)"]
        var params: [SQLiteValue] = [SQLiteValue(scope.showAdult), SQLiteValue(scope.allRegions)]
        appendCommon(to: &clauses, params: &params, filter: filter, genreTable: "series_genre", idColumn: "series_id", hasDuration: false)
        return (clauses.joined(separator: " AND "), params)
    }

    private func channelWhere(category: String?, _ scope: Scope) -> (String, [SQLiteValue]) {
        var clauses = ["(? OR is_adult = 0)", "(? OR is_relevant = 1)"]
        var params: [SQLiteValue] = [SQLiteValue(scope.showAdult), SQLiteValue(scope.allRegions)]
        if let category, category != "All" {
            clauses.append("category = ?")
            params.append(.text(category))
        }
        return (clauses.joined(separator: " AND "), params)
    }

    private func appendCommon(
        to clauses: inout [String], params: inout [SQLiteValue],
        filter: CatalogFilter, genreTable: String, idColumn: String, hasDuration: Bool
    ) {
        if !filter.genres.isEmpty {
            let ph = Array(repeating: "?", count: filter.genres.count).joined(separator: ",")
            clauses.append("id IN (SELECT \(idColumn) FROM \(genreTable) WHERE genre IN (\(ph)))")
            params += filter.genres.map { SQLiteValue.text($0.rawValue) }
        }
        for lang in filter.audioLanguages {
            clauses.append("instr(audio_langs, ?) > 0")
            params.append(.text(CatalogValues.needle(lang)))
        }
        for lang in filter.subtitleLanguages {
            clauses.append("instr(sub_langs, ?) > 0")
            params.append(.text(CatalogValues.needle(lang)))
        }
        if let minYear = filter.minYear {
            clauses.append("year IS NOT NULL AND year >= ?")
            params.append(.integer(Int64(minYear)))
        }
        if let maxYear = filter.maxYear {
            clauses.append("year IS NOT NULL AND year <= ?")
            params.append(.integer(Int64(maxYear)))
        }
        if let minQuality = filter.minQuality, minQuality > .unknown {
            clauses.append("(CASE quality WHEN 'uhd' THEN 4 WHEN 'fhd' THEN 3 WHEN 'hd' THEN 2 WHEN 'sd' THEN 1 ELSE 0 END) >= ?")
            params.append(.integer(Int64(qualityRank(minQuality))))
        }
        if hasDuration, let maxDuration = filter.maxDurationMinutes {
            clauses.append("(duration_min IS NULL OR duration_min <= ?)")
            params.append(.integer(Int64(maxDuration)))
        }
        let needle = filter.text.foldedForSearch()
        if !needle.isEmpty {
            clauses.append("instr(title_fold, ?) > 0")
            params.append(.text(needle))
        }
    }

    private func qualityRank(_ q: VideoQuality) -> Int {
        switch q {
        case .unknown: return 0
        case .sd:      return 1
        case .hd:      return 2
        case .fhd:     return 3
        case .uhd:     return 4
        }
    }

    private static func orderClause(_ sort: BrowseSort) -> String {
        switch sort {
        case .recentlyAdded:  return "(added_at IS NULL), added_at DESC, title_fold"
        case .titleAscending: return "title_fold, (year IS NULL), year"
        case .newest:         return "(year IS NULL), year DESC, title_fold"
        case .oldest:         return "(year IS NULL), year ASC, title_fold"
        }
    }

    // MARK: - Writes

    /// Wipe every catalog table (keeps `meta`), inside one transaction.
    public func clearCatalog() throws {
        try connection.transaction {
            for table in ["channel", "movie", "movie_genre", "series", "series_genre", "episode", "epg_event"] {
                try connection.execute("DELETE FROM \(table)")
            }
        }
    }

    public func insertChannels(_ channels: [Channel], homeRegions: Set<String>) throws {
        let rows = channels.map { channel -> [SQLiteValue] in
            let relevant = RelevanceFilter.isRelevant(countryCode: channel.countryCode, name: channel.name, category: channel.category)
            return [
                .text(channel.id.rawValue),
                .text(channel.name),
                .text(channel.name.foldedForSearch()),
                .text(channel.category),
                SQLiteValue(channel.logoURL),
                SQLiteValue(channel.countryCode),
                .text(CatalogValues.encode(channel.audioLanguages)),
                .text(CatalogValues.encode(channel.subtitleLanguages)),
                .text(CatalogValues.encode(channel.quality)),
                .text(channel.streamURL.absoluteString),
                SQLiteValue(channel.epgID),
                .integer(Int64(channel.sortIndex)),
                SQLiteValue(channel.isAdult),
                SQLiteValue(relevant),
                .integer(Int64(RelevanceFilter.priority(countryCode: channel.countryCode, home: homeRegions))),
            ]
        }
        try connection.transaction {
            try connection.executeMany("""
            INSERT OR REPLACE INTO channel
            (id, name, name_fold, category, logo_url, country_code, audio_langs, sub_langs, quality,
             stream_url, epg_id, sort_index, is_adult, is_relevant, region_priority)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, rows)
        }
    }

    public func insertMovies(_ movies: [Movie]) throws {
        let rows = movies.map { movie -> [SQLiteValue] in
            let relevant = RelevanceFilter.isRelevant(
                countryCode: movie.countryCode, name: movie.title, category: movie.genres.first?.displayName ?? ""
            )
            return [
                .text(movie.id.rawValue),
                .text(movie.title),
                .text(movie.title.foldedForSearch()),
                SQLiteValue(movie.year),
                SQLiteValue(movie.durationMinutes),
                .text(CatalogValues.encode(movie.audioLanguages)),
                .text(CatalogValues.encode(movie.subtitleLanguages)),
                .text(CatalogValues.encode(movie.genres)),
                .text(CatalogValues.encode(movie.quality)),
                SQLiteValue(movie.countryCode),
                SQLiteValue(movie.posterURL),
                SQLiteValue(movie.backdropURL),
                SQLiteValue(movie.synopsis),
                .text(CatalogValues.encode(list: movie.cast)),
                .text(CatalogValues.encode(list: movie.directors)),
                .text(movie.streamURL.absoluteString),
                SQLiteValue(date: movie.addedAt),
                SQLiteValue(movie.isAdult),
                SQLiteValue(relevant),
            ]
        }
        let genreRows = movies.flatMap { movie in
            movie.genres.map { [SQLiteValue.text(movie.id.rawValue), .text($0.rawValue)] }
        }
        try connection.transaction {
            try connection.executeMany("""
            INSERT OR REPLACE INTO movie
            (id, title, title_fold, year, duration_min, audio_langs, sub_langs, genres, quality,
             country_code, poster_url, backdrop_url, synopsis, cast_list, directors, stream_url,
             added_at, is_adult, is_relevant)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, rows)
            try connection.executeMany(
                "INSERT OR IGNORE INTO movie_genre (movie_id, genre) VALUES (?,?)", genreRows
            )
        }
    }

    public func insertSeries(_ series: [Series]) throws {
        let rows = series.map { show -> [SQLiteValue] in
            let relevant = RelevanceFilter.isRelevant(
                countryCode: show.countryCode, name: show.title, category: show.genres.first?.displayName ?? ""
            )
            return [
                .text(show.id.rawValue),
                .text(show.title),
                .text(show.title.foldedForSearch()),
                SQLiteValue(show.year),
                .text(CatalogValues.encode(show.audioLanguages)),
                .text(CatalogValues.encode(show.subtitleLanguages)),
                .text(CatalogValues.encode(show.genres)),
                .text(CatalogValues.encode(show.quality)),
                SQLiteValue(show.countryCode),
                SQLiteValue(show.posterURL),
                SQLiteValue(show.backdropURL),
                SQLiteValue(show.synopsis),
                SQLiteValue(show.providerSeriesKey),
                SQLiteValue(date: show.addedAt),
                SQLiteValue(show.isAdult),
                SQLiteValue(relevant),
                .integer(show.seasons.isEmpty ? 0 : 1),
            ]
        }
        let genreRows = series.flatMap { show in
            show.genres.map { [SQLiteValue.text(show.id.rawValue), .text($0.rawValue)] }
        }
        let episodeRows = series.flatMap { $0.seasons.flatMap(\.episodes) }.map(Self.episodeRow)

        try connection.transaction {
            try connection.executeMany("""
            INSERT OR REPLACE INTO series
            (id, title, title_fold, year, audio_langs, sub_langs, genres, quality, country_code,
             poster_url, backdrop_url, synopsis, provider_key, added_at, is_adult, is_relevant, seasons_loaded)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, rows)
            try connection.executeMany(
                "INSERT OR IGNORE INTO series_genre (series_id, genre) VALUES (?,?)", genreRows
            )
            try connection.executeMany("""
            INSERT OR REPLACE INTO episode
            (id, series_id, season, episode, title, overview, duration_min, still_url, stream_url)
            VALUES (?,?,?,?,?,?,?,?,?)
            """, episodeRows)
        }
    }

    /// Replace one series' episodes after an on-demand fetch (Xtream).
    public func replaceSeasons(_ seasons: [Season], seriesID: CatalogID) throws {
        let episodeRows = seasons.flatMap(\.episodes).map(Self.episodeRow)
        try connection.transaction {
            try connection.run("DELETE FROM episode WHERE series_id = ?", [.text(seriesID.rawValue)])
            try connection.executeMany("""
            INSERT OR REPLACE INTO episode
            (id, series_id, season, episode, title, overview, duration_min, still_url, stream_url)
            VALUES (?,?,?,?,?,?,?,?,?)
            """, episodeRows)
            try connection.run("UPDATE series SET seasons_loaded = 1 WHERE id = ?", [.text(seriesID.rawValue)])
        }
    }

    private static func episodeRow(_ episode: Episode) -> [SQLiteValue] {
        [
            .text(episode.id.rawValue),
            .text(episode.seriesID.rawValue),
            .integer(Int64(episode.seasonNumber)),
            .integer(Int64(episode.episodeNumber)),
            .text(episode.title),
            SQLiteValue(episode.overview),
            SQLiteValue(episode.durationMinutes),
            SQLiteValue(episode.stillURL),
            .text(episode.streamURL.absoluteString),
        ]
    }

    /// Insert an EPG batch, dropping anything outside `window` before it touches
    /// the database so `epg_event` never scales with the size of the feed.
    public func insertEPG(_ events: [EPGEvent], window: DateInterval) throws {
        let rows = events.compactMap { event -> [SQLiteValue]? in
            guard event.stop > window.start, event.start < window.end else { return nil }
            return [
                .text(event.channelEPGID),
                .text(event.title),
                SQLiteValue(event.subtitle),
                SQLiteValue(event.description),
                .real(event.start.timeIntervalSince1970),
                .real(event.stop.timeIntervalSince1970),
                SQLiteValue(event.category),
            ]
        }
        try connection.transaction {
            try connection.executeMany("""
            INSERT OR IGNORE INTO epg_event
            (channel_epg_id, title, subtitle, description, start_at, stop_at, category)
            VALUES (?,?,?,?,?,?,?)
            """, rows)
        }
    }

    // MARK: - Dynamic query state (columns, not app state)

    public func updateRegionPriorities(homeRegions: Set<String>) throws {
        let rows = try connection.query("SELECT id, country_code FROM channel") {
            ($0.string(0), $0.stringOrNil(1))
        }
        let updates = rows.map { id, country in
            [SQLiteValue.integer(Int64(RelevanceFilter.priority(countryCode: country, home: homeRegions))), .text(id)]
        }
        try connection.transaction {
            try connection.executeMany("UPDATE channel SET region_priority = ? WHERE id = ?", updates)
        }
    }

    public func updateRecentChannels(_ ids: [CatalogID]) throws {
        try connection.transaction {
            try connection.execute("UPDATE channel SET recent_rank = NULL WHERE recent_rank IS NOT NULL")
            let updates = ids.enumerated().map { index, id in
                [SQLiteValue.integer(Int64(index)), .text(id.rawValue)]
            }
            try connection.executeMany("UPDATE channel SET recent_rank = ? WHERE id = ?", updates)
        }
    }

    // MARK: - Maintenance

    /// Reclaim pages and refresh the query planner's statistics after a big
    /// import. Cheap enough to run once per import.
    public func optimize() throws {
        try connection.execute("PRAGMA optimize")
        try connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    }
}
