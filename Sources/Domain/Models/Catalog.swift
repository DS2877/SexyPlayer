import Foundation

/// The full normalised library from one provider. Held in memory and persisted
/// to disk as JSON between launches (see `CatalogCache`); an indexed SQLite
/// store is the planned upgrade for very large libraries.
public struct Catalog: Sendable, Codable {
    public var channels: [Channel]
    public var movies: [Movie]
    public var series: [Series]
    public var epg: [EPGEvent]

    public init(
        channels: [Channel] = [],
        movies: [Movie] = [],
        series: [Series] = [],
        epg: [EPGEvent] = []
    ) {
        self.channels = channels
        self.movies = movies
        self.series = series
        self.epg = epg
    }

    public var isEmpty: Bool {
        channels.isEmpty && movies.isEmpty && series.isEmpty
    }

    /// Events on a given EPG channel that overlap the window, sorted by start.
    public func events(forEPGID epgID: String, in window: DateInterval) -> [EPGEvent] {
        epg
            .filter { $0.channelEPGID == epgID && $0.stop > window.start && $0.start < window.end }
            .sorted { $0.start < $1.start }
    }

    /// The programme airing on a channel at `date`, if any.
    public func nowPlaying(forEPGID epgID: String, at date: Date) -> EPGEvent? {
        epg.first { $0.channelEPGID == epgID && $0.isLive(at: date) }
    }
}
