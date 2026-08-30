import Foundation

/// Provider-shaped, un-normalised data. This is the *only* place messy strings
/// like `"SE | TV4 HD [1080p]"` are allowed to exist. The Normalizer consumes
/// this and produces `Catalog`.
public struct RawCatalog: Sendable {
    public var providerID: String
    public var channels: [RawChannel]
    public var vod: [RawVODItem]
    /// Episodes whose series structure must be reconstructed from names (M3U).
    public var seriesEpisodes: [RawSeriesEpisode]
    /// Series known only as metadata; episodes fetched on demand (Xtream).
    public var seriesShells: [RawSeriesShell]
    public var epg: [RawEPGEvent]

    public init(
        providerID: String,
        channels: [RawChannel] = [],
        vod: [RawVODItem] = [],
        seriesEpisodes: [RawSeriesEpisode] = [],
        seriesShells: [RawSeriesShell] = [],
        epg: [RawEPGEvent] = []
    ) {
        self.providerID = providerID
        self.channels = channels
        self.vod = vod
        self.seriesEpisodes = seriesEpisodes
        self.seriesShells = seriesShells
        self.epg = epg
    }
}

/// A series known to exist, without its episode list yet.
public struct RawSeriesShell: Sendable {
    public let providerKey: String
    public let name: String
    public let cover: String?
    public let plot: String?
    public let genreText: String?
    public let cast: String?
    public let director: String?
    public let releaseDate: String?
    public let groupTitle: String?
    public let addedAt: Date?

    public init(providerKey: String, name: String, cover: String? = nil, plot: String? = nil, genreText: String? = nil, cast: String? = nil, director: String? = nil, releaseDate: String? = nil, groupTitle: String? = nil, addedAt: Date? = nil) {
        self.providerKey = providerKey
        self.name = name
        self.cover = cover
        self.plot = plot
        self.genreText = genreText
        self.cast = cast
        self.director = director
        self.releaseDate = releaseDate
        self.groupTitle = groupTitle
        self.addedAt = addedAt
    }
}

public struct RawChannel: Sendable {
    /// Provider's own stable key for this stream (Xtream stream_id, or the M3U
    /// url/tvg-id). Used to derive `CatalogID`.
    public let providerKey: String
    public let displayName: String
    public let groupTitle: String?
    public let logo: String?
    public let tvgID: String?
    public let streamURL: String
    /// The provider's channel number / list position, for "sort by number".
    public let channelNumber: Int?

    public init(providerKey: String, displayName: String, groupTitle: String?, logo: String?, tvgID: String?, streamURL: String, channelNumber: Int? = nil) {
        self.providerKey = providerKey
        self.displayName = displayName
        self.groupTitle = groupTitle
        self.logo = logo
        self.tvgID = tvgID
        self.streamURL = streamURL
        self.channelNumber = channelNumber
    }
}

public struct RawVODItem: Sendable {
    public let providerKey: String
    public let name: String
    public let groupTitle: String?
    public let logo: String?
    public let streamURL: String
    /// Optional provider-supplied metadata (Xtream sometimes has this).
    public let plot: String?
    public let genreText: String?
    public let releaseDate: String?
    public let durationSecs: Int?
    public let cast: String?
    public let director: String?
    public let addedAt: Date?

    public init(providerKey: String, name: String, groupTitle: String?, logo: String?, streamURL: String, plot: String? = nil, genreText: String? = nil, releaseDate: String? = nil, durationSecs: Int? = nil, cast: String? = nil, director: String? = nil, addedAt: Date? = nil) {
        self.providerKey = providerKey
        self.name = name
        self.groupTitle = groupTitle
        self.logo = logo
        self.streamURL = streamURL
        self.plot = plot
        self.genreText = genreText
        self.releaseDate = releaseDate
        self.durationSecs = durationSecs
        self.cast = cast
        self.director = director
        self.addedAt = addedAt
    }
}

/// One raw episode row. Series/season structure is *reconstructed* by the
/// Normalizer from names like `"The Last of Us S01E03"` — providers rarely give
/// clean structure in M3U.
public struct RawSeriesEpisode: Sendable {
    public let providerKey: String
    public let name: String
    public let groupTitle: String?
    public let logo: String?
    public let streamURL: String
    public let plot: String?
    /// Present when the provider *did* give structured fields (Xtream series API).
    public let explicitSeriesName: String?
    public let explicitSeason: Int?
    public let explicitEpisode: Int?

    public init(providerKey: String, name: String, groupTitle: String?, logo: String?, streamURL: String, plot: String? = nil, explicitSeriesName: String? = nil, explicitSeason: Int? = nil, explicitEpisode: Int? = nil) {
        self.providerKey = providerKey
        self.name = name
        self.groupTitle = groupTitle
        self.logo = logo
        self.streamURL = streamURL
        self.plot = plot
        self.explicitSeriesName = explicitSeriesName
        self.explicitSeason = explicitSeason
        self.explicitEpisode = explicitEpisode
    }
}

public struct RawEPGEvent: Sendable {
    public let channelID: String
    public let title: String
    public let subtitle: String?
    public let description: String?
    public let start: Date
    public let stop: Date
    public let category: String?

    public init(channelID: String, title: String, subtitle: String? = nil, description: String? = nil, start: Date, stop: Date, category: String? = nil) {
        self.channelID = channelID
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.start = start
        self.stop = stop
        self.category = category
    }
}
