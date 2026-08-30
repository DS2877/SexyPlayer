import Foundation
import Observation

@MainActor
@Observable
public final class HomeViewModel {

    public private(set) var content: HomeContent = .empty
    public private(set) var isBuilding = false

    private let repository: any CatalogRepository
    private let watchProgress: WatchProgressStore
    private let preferences: PreferencesStore
    private let metadata: MetadataService

    public init(repository: any CatalogRepository,
                watchProgress: WatchProgressStore,
                preferences: PreferencesStore,
                metadata: MetadataService) {
        self.repository = repository
        self.watchProgress = watchProgress
        self.preferences = preferences
        self.metadata = metadata
    }

    public func rebuild(now: Date = .now) async {
        isBuilding = true
        defer { isBuilding = false }

        // Gather Sendable inputs on the main actor, then do the heavy shaping
        // (sorts/filters over tens of thousands of items) off it.
        let catalog = await repository.snapshot()
        guard !catalog.isEmpty else { content = .empty; return }
        let epg = await repository.epgIndex()
        let prefs = preferences.preferences
        let progress = watchProgress.allEntries()
        let ratings = await metadata.ratingsSnapshot()

        content = await Task.detached(priority: .userInitiated) {
            Self.makeContent(catalog: catalog, epg: epg, progress: progress,
                             prefs: prefs, ratings: ratings, now: now)
        }.value
    }

    // MARK: - Pure builder (runs off the main actor)

    nonisolated static func makeContent(
        catalog: Catalog, epg: EPGIndex, progress: [WatchProgress],
        prefs: UserPreferences, ratings: [String: Double], now: Date
    ) -> HomeContent {
        let enabled = Set(prefs.homeRows)
        var rows: [HomeRow] = []

        func add(_ kind: HomeRowKind, _ title: String, _ cards: [HomeCard], subtitle: String? = nil) {
            guard enabled.contains(kind), !cards.isEmpty else { return }
            rows.append(HomeRow(id: kind.rawValue, title: title, subtitle: subtitle, cards: cards))
        }

        // Movies sorted by recency once, reused for the shelf + hero.
        let moviesByRecency = catalog.movies.sorted { lhs, rhs in
            let l = lhs.addedAt ?? .distantPast, r = rhs.addedAt ?? .distantPast
            if l != r { return l > r }
            return (lhs.year ?? 0) > (rhs.year ?? 0)
        }

        add(.continueWatching, "Continue Watching", continueWatchingCards(catalog: catalog, progress: progress))

        let liveCards = catalog.channels.prefix(16).map { channel -> HomeCard in
            let event = channel.epgID.flatMap { epg.nowPlaying(forChannel: $0, at: now) }
            return HomeCard(id: channel.id, kind: .channel, title: channel.name,
                            subtitle: event?.title ?? channel.category,
                            artworkURL: channel.logoURL, badge: event != nil ? "LIVE" : nil)
        }
        add(.liveNow, "Live Now", Array(liveCards))

        let seriesByRecency = catalog.series.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
        var recent = Array(moviesByRecency.prefix(12)).map { card(for: $0) }
        recent += Array(seriesByRecency.prefix(6)).map { card(for: $0) }
        add(.recentlyAdded, "Recently Added", Array(recent.prefix(16)))

        if !prefs.preferredAudioLanguages.isEmpty {
            let want = Set(prefs.preferredAudioLanguages)
            var cards = catalog.movies.filter { !want.isDisjoint(with: $0.audioLanguages) }.prefix(20).map { card(for: $0) }
            cards += catalog.series.filter { !want.isDisjoint(with: $0.audioLanguages) }.prefix(10).map { card(for: $0) }
            add(.inYourLanguages, "In Your Languages", cards)
        }
        if let sub = prefs.preferredSubtitleLanguage {
            var cards = catalog.movies.filter { $0.subtitleLanguages.contains(sub) }.prefix(20).map { card(for: $0) }
            cards += catalog.series.filter { $0.subtitleLanguages.contains(sub) }.prefix(10).map { card(for: $0) }
            add(.withYourSubtitles, "With \(sub.displayName) Subtitles", cards)
        }

        // Top Rated — TMDB ratings, best first. Shown whenever we have enough
        // rated titles, regardless of the saved row toggles (it's new).
        let ratedMovies = catalog.movies.compactMap { m in
            ratings[m.id.rawValue].map { (card: card(for: m), score: $0) }
        }
        let ratedSeries = catalog.series.compactMap { s in
            ratings[s.id.rawValue].map { (card: card(for: s), score: $0) }
        }
        let ratedCards = ratedMovies + ratedSeries
        let topRated = ratedCards
            .filter { $0.score >= 7.0 }
            .sorted { $0.score > $1.score }
            .prefix(24)
            .map(\.card)
        if topRated.count >= 5 {
            rows.append(HomeRow(id: HomeRowKind.topRated.rawValue, title: "Top Rated",
                                subtitle: "Highest rated in your library", cards: Array(topRated)))
        }

        // Genre shelves — the biggest few genres in the library. Like "Top
        // Rated" these are new, so they're shown regardless of the saved row
        // list (which predates the option); a future opt-out can gate them.
        var genreRows: [HomeRow] = []
        do {
            var counts: [Genre: Int] = [:]
            for movie in catalog.movies { for g in movie.genres { counts[g, default: 0] += 1 } }
            for series in catalog.series { for g in series.genres { counts[g, default: 0] += 1 } }
            let topGenres = counts.sorted { $0.value > $1.value }.prefix(5).map(\.key)
            for genre in topGenres where counts[genre, default: 0] >= 8 {
                var cards = Array(moviesByRecency.lazy.filter { $0.genres.contains(genre) }.prefix(18))
                    .map { card(for: $0) }
                cards += Array(seriesByRecency.lazy.filter { $0.genres.contains(genre) }.prefix(6))
                    .map { card(for: $0) }
                if cards.count >= 5 {
                    genreRows.append(HomeRow(id: "genre-\(genre.rawValue)", title: genre.displayName,
                                             subtitle: nil, cards: Array(cards.prefix(22))))
                }
            }
        }

        add(.movies, "Movies", Array(moviesByRecency.prefix(30)).map { card(for: $0) })
        add(.series, "Series", Array(catalog.series.prefix(30)).map { card(for: $0) })

        // Match the user's preferred row order.
        rows.sort { lhs, rhs in
            (prefs.homeRows.firstIndex { $0.rawValue == lhs.id } ?? 99)
                < (prefs.homeRows.firstIndex { $0.rawValue == rhs.id } ?? 99)
        }

        // Float "Top Rated" up just below Continue Watching (it has no saved
        // position to sort by).
        if let idx = rows.firstIndex(where: { $0.id == HomeRowKind.topRated.rawValue }) {
            let row = rows.remove(at: idx)
            let insertAt = rows.firstIndex { $0.id == HomeRowKind.continueWatching.rawValue }
                .map { $0 + 1 } ?? 0
            rows.insert(row, at: Swift.min(insertAt, rows.count))
        }

        // Genre shelves sit just above the generic Movies / Series shelves.
        if !genreRows.isEmpty {
            let anchor = rows.firstIndex {
                $0.id == HomeRowKind.movies.rawValue || $0.id == HomeRowKind.series.rawValue
            } ?? rows.count
            rows.insert(contentsOf: genreRows, at: anchor)
        }

        let hero = moviesByRecency.first.map { movie in
            HomeCard(id: movie.id, kind: .movie, title: movie.title, subtitle: movie.synopsis,
                     artworkURL: movie.backdropURL ?? movie.posterURL, eyebrow: metadataSubtitle(for: movie))
        }

        let tonight = prefs.isRowEnabled(.tonight)
            ? buildTonight(channels: catalog.channels, epg: epg, now: now) : []

        return HomeContent(hero: hero, rows: rows.filter { !$0.cards.isEmpty }, tonight: tonight)
    }

    nonisolated private static func continueWatchingCards(catalog: Catalog, progress: [WatchProgress]) -> [HomeCard] {
        UpNext.resumePoints(catalog: catalog, progress: progress, limit: 12).map { point in
            HomeCard(id: point.containerID, kind: point.isSeries ? .series : .movie,
                     title: point.primaryTitle, subtitle: point.secondaryText,
                     artworkURL: point.artworkURL, progress: point.fraction > 0 ? point.fraction : nil)
        }
    }

    nonisolated static func buildTonight(channels: [Channel], epg: EPGIndex, now: Date) -> [TonightItem] {
        let cal = Calendar(identifier: .gregorian)
        let endWindow = cal.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? now
        let window = DateInterval(start: now, end: max(now, endWindow))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        var items: [TonightItem] = []
        for channel in channels {
            guard let epgID = channel.epgID, epg[epgID] != nil else { continue }
            for event in epg.events(forChannel: epgID, in: window).prefix(3) {
                items.append(TonightItem(id: event.id, channelID: channel.id,
                                         time: formatter.string(from: event.start),
                                         programTitle: event.title, channelName: channel.name,
                                         isLiveNow: event.isLive(at: now)))
            }
            if items.count > 60 { break }
        }
        return Array(items.sorted { $0.time < $1.time }.prefix(12))
    }

    nonisolated static func card(for movie: Movie) -> HomeCard {
        HomeCard(id: movie.id, kind: .movie, title: movie.title,
                 subtitle: metadataSubtitle(for: movie), artworkURL: movie.posterURL, year: movie.year)
    }

    nonisolated static func card(for series: Series) -> HomeCard {
        HomeCard(id: series.id, kind: .series, title: series.title,
                 subtitle: "\(series.seasons.count) season\(series.seasons.count == 1 ? "" : "s")",
                 artworkURL: series.posterURL, year: series.year)
    }

    nonisolated static func metadataSubtitle(for movie: Movie) -> String {
        var parts: [String] = []
        if let year = movie.year { parts.append(String(year)) }
        if let genre = movie.genres.first { parts.append(genre.displayName) }
        if let d = movie.durationMinutes { parts.append("\(d / 60)h \(d % 60)m") }
        if movie.quality > .unknown { parts.append(movie.quality.shortLabel) }
        return parts.joined(separator: " · ")
    }
}
