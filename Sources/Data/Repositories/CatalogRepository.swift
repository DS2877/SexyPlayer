import Foundation

/// Read model the feature layer depends on. In M1 this is backed by SQLite with
/// paginated queries; in M0 it's an in-memory implementation over `Catalog`.
///
/// Every method is async so the SQLite implementation can hop to a background
/// executor without changing call sites.
public protocol CatalogRepository: Sendable {
    /// True once a catalog has been loaded.
    func isReady() async -> Bool

    /// When `true`, every query and `snapshot()` excludes adult-flagged items.
    func setHideAdult(_ hide: Bool) async

    func channels(in category: String?, sort: ChannelSort, page: Int, pageSize: Int) async -> [Channel]
    func channelTitleAnchors(in category: String?) async -> [BrowseAnchor]
    func allChannelCategories() async -> [String]

    func movies(filter: CatalogFilter, page: Int, pageSize: Int) async -> [Movie]
    func series(filter: CatalogFilter, page: Int, pageSize: Int) async -> [Series]

    /// First-letter jump targets for the A–Z browse index (title-sorted list).
    func movieTitleAnchors(filter: CatalogFilter) async -> [BrowseAnchor]
    func seriesTitleAnchors(filter: CatalogFilter) async -> [BrowseAnchor]

    func moviesCount(filter: CatalogFilter) async -> Int
    func seriesCount(filter: CatalogFilter) async -> Int
    func channelsCount(in category: String?) async -> Int

    /// Genres actually present among movies + series — for the filter UI.
    func availableGenres() async -> [Genre]
    func availableAudioLanguages() async -> [Language]
    func availableSubtitleLanguages() async -> [Language]

    func movie(id: CatalogID) async -> Movie?
    func series(id: CatalogID) async -> Series?
    func channel(id: CatalogID) async -> Channel?

    /// Attach on-demand-loaded episodes to a series shell.
    func attachSeasons(_ seasons: [Season], toSeriesID id: CatalogID) async

    func recentlyAdded(limit: Int) async -> [SearchResult.Item]

    /// EPG events for a channel within a window.
    func epgEvents(forEPGID epgID: String, in window: DateInterval) async -> [EPGEvent]
    func nowPlaying(forEPGID epgID: String, at date: Date) async -> EPGEvent?

    /// The whole EPG grouped by channel (each list sorted by start). Cheap to
    /// return — callers window it locally instead of scanning the flat array.
    func epgIndex() async -> [String: [EPGEvent]]

    /// Full snapshot — used by the search engine in M0. In M1 the search engine
    /// queries the FTS index instead.
    func snapshot() async -> Catalog
}

/// Composable, structured filter used by browse screens (distinct from
/// `SearchIntent`, which is the *parsed* form of a natural-language query —
/// though a `SearchIntent` maps cleanly onto a `CatalogFilter`).
/// A first-letter jump target for an A–Z browse list.
public struct BrowseAnchor: Identifiable, Sendable, Hashable {
    public let letter: String   // "A"…"Z" or "#"
    public let index: Int       // position in the sorted+filtered list
    public var id: String { letter }

    public init(letter: String, index: Int) {
        self.letter = letter
        self.index = index
    }
}

public enum ChannelSort: String, CaseIterable, Sendable {
    case number
    case nameAsc

    public var label: String {
        switch self {
        case .number:  return "Channel no."
        case .nameAsc: return "A–Z"
        }
    }
}

public enum BrowseSort: String, CaseIterable, Sendable, Codable {
    case recentlyAdded
    case titleAscending
    case newest
    case oldest

    public var label: String {
        switch self {
        case .recentlyAdded:  return "Recently Added"
        case .titleAscending: return "A–Z"
        case .newest:         return "Newest"
        case .oldest:         return "Oldest"
        }
    }
}

public struct CatalogFilter: Equatable, Sendable {
    public var genres: [Genre]
    public var audioLanguages: [Language]
    public var subtitleLanguages: [Language]
    public var minYear: Int?
    public var maxYear: Int?
    public var maxDurationMinutes: Int?
    public var minQuality: VideoQuality?
    public var text: String
    public var sort: BrowseSort

    public init(
        genres: [Genre] = [],
        audioLanguages: [Language] = [],
        subtitleLanguages: [Language] = [],
        minYear: Int? = nil,
        maxYear: Int? = nil,
        maxDurationMinutes: Int? = nil,
        minQuality: VideoQuality? = nil,
        text: String = "",
        sort: BrowseSort = .titleAscending
    ) {
        self.genres = genres
        self.audioLanguages = audioLanguages
        self.subtitleLanguages = subtitleLanguages
        self.minYear = minYear
        self.maxYear = maxYear
        self.maxDurationMinutes = maxDurationMinutes
        self.minQuality = minQuality
        self.text = text
        self.sort = sort
    }

    /// Whether any narrowing filter is active (ignores sort + text).
    public var isNarrowed: Bool {
        !genres.isEmpty || !audioLanguages.isEmpty || !subtitleLanguages.isEmpty
            || minYear != nil || maxYear != nil || maxDurationMinutes != nil || minQuality != nil
    }

    public var activeChips: [String] {
        var chips: [String] = []
        chips += genres.map(\.displayName)
        chips += audioLanguages.map { "\($0.displayName) audio" }
        chips += subtitleLanguages.map { "\($0.displayName) subs" }
        if let minYear, let maxYear { chips.append("\(minYear)–\(maxYear)") }
        else if let minYear { chips.append("From \(minYear)") }
        else if let maxYear { chips.append("Until \(maxYear)") }
        if let minQuality, minQuality > .unknown { chips.append("\(minQuality.shortLabel)+") }
        return chips
    }

    public static let none = CatalogFilter()

    public init(intent: SearchIntent) {
        let sort: BrowseSort = intent.sort == .newest ? .newest : .titleAscending
        self.init(
            genres: intent.genres,
            audioLanguages: intent.audioLanguages,
            subtitleLanguages: intent.subtitleLanguages,
            minYear: intent.minYear,
            maxYear: intent.maxYear,
            maxDurationMinutes: intent.maxDurationMinutes,
            minQuality: intent.minQuality,
            text: intent.freeText,
            sort: sort
        )
    }
}
