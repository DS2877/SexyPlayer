import Foundation

/// Read model the feature layer depends on. In M1 this is backed by SQLite with
/// paginated queries; in M0 it's an in-memory implementation over `Catalog`.
///
/// Every method is async so the SQLite implementation can hop to a background
/// executor without changing call sites.
public protocol CatalogRepository: Sendable {
    /// True once a catalog has been loaded.
    func isReady() async -> Bool

    func channels(in category: String?, page: Int, pageSize: Int) async -> [Channel]
    func allChannelCategories() async -> [String]

    func movies(filter: CatalogFilter, page: Int, pageSize: Int) async -> [Movie]
    func series(filter: CatalogFilter, page: Int, pageSize: Int) async -> [Series]

    func movie(id: CatalogID) async -> Movie?
    func series(id: CatalogID) async -> Series?
    func channel(id: CatalogID) async -> Channel?

    /// Attach on-demand-loaded episodes to a series shell.
    func attachSeasons(_ seasons: [Season], toSeriesID id: CatalogID) async

    func recentlyAdded(limit: Int) async -> [SearchResult.Item]

    /// EPG events for a channel within a window.
    func epgEvents(forEPGID epgID: String, in window: DateInterval) async -> [EPGEvent]
    func nowPlaying(forEPGID epgID: String, at date: Date) async -> EPGEvent?

    /// Full snapshot — used by the search engine in M0. In M1 the search engine
    /// queries the FTS index instead.
    func snapshot() async -> Catalog
}

/// Composable, structured filter used by browse screens (distinct from
/// `SearchIntent`, which is the *parsed* form of a natural-language query —
/// though a `SearchIntent` maps cleanly onto a `CatalogFilter`).
public struct CatalogFilter: Equatable, Sendable {
    public var genres: [Genre]
    public var audioLanguages: [Language]
    public var subtitleLanguages: [Language]
    public var minYear: Int?
    public var maxYear: Int?
    public var maxDurationMinutes: Int?
    public var minQuality: VideoQuality?
    public var text: String

    public init(
        genres: [Genre] = [],
        audioLanguages: [Language] = [],
        subtitleLanguages: [Language] = [],
        minYear: Int? = nil,
        maxYear: Int? = nil,
        maxDurationMinutes: Int? = nil,
        minQuality: VideoQuality? = nil,
        text: String = ""
    ) {
        self.genres = genres
        self.audioLanguages = audioLanguages
        self.subtitleLanguages = subtitleLanguages
        self.minYear = minYear
        self.maxYear = maxYear
        self.maxDurationMinutes = maxDurationMinutes
        self.minQuality = minQuality
        self.text = text
    }

    public static let none = CatalogFilter()

    public init(intent: SearchIntent) {
        self.init(
            genres: intent.genres,
            audioLanguages: intent.audioLanguages,
            subtitleLanguages: intent.subtitleLanguages,
            minYear: intent.minYear,
            maxYear: intent.maxYear,
            maxDurationMinutes: intent.maxDurationMinutes,
            minQuality: intent.minQuality,
            text: intent.freeText
        )
    }
}
