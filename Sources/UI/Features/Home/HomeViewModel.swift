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
        // Already ranked: regulars first, then home country, then the rest.
        let liveNow = await repository.channels(in: nil, sort: .number, page: 0, pageSize: 18)

        content = await Task.detached(priority: .userInitiated) {
            Self.makeContent(catalog: catalog, epg: epg, progress: progress,
                             prefs: prefs, ratings: ratings, liveNow: liveNow, now: now)
        }.value
    }

    // MARK: - Pure builder (runs off the main actor)

    nonisolated static func makeContent(
        catalog: Catalog, epg: EPGIndex, progress: [WatchProgress],
        prefs: UserPreferences, ratings: [String: Double], liveNow: [Channel], now: Date
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

        let liveCards = liveNow.prefix(16).map { channel -> HomeCard in
            let event = channel.epgID.flatMap { epg.nowPlaying(forChannel: $0, at: now) }
            return HomeCard(id: channel.id, kind: .channel, title: channel.name,
                            subtitle: event?.title ?? channel.category,
                            artworkURL: channel.logoURL, badge: event != nil ? "LIVE" : nil,
                            liveProgress: event?.progress(at: now))
        }
        add(.liveNow, "Live Now", Array(liveCards))

        let seriesByRecency = catalog.series.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }

        // "Because You Watched X" — genre-similar titles to the newest thing the
        // viewer has played. Floated just under Continue Watching below.
        let becauseRow: HomeRow? = {
            guard let anchor = mostRecentWatched(progress: progress, catalog: catalog) else { return nil }
            let cards = similarTitles(toGenres: anchor.genres, excluding: anchor.id,
                                      movies: moviesByRecency, series: seriesByRecency, limit: 20)
            guard cards.count >= 5 else { return nil }
            return HomeRow(id: "because-\(anchor.id.rawValue)",
                           title: "Because You Watched \(anchor.title)", subtitle: nil, cards: cards)
        }()

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
        if let becauseRow { rows.append(becauseRow) }

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

        // Float "Top Rated" then "Because You Watched" up just below Continue
        // Watching (neither has a saved position to sort by).
        for floatID in [HomeRowKind.topRated.rawValue, becauseRow?.id].compactMap({ $0 }) {
            guard let idx = rows.firstIndex(where: { $0.id == floatID }) else { continue }
            let row = rows.remove(at: idx)
            let insertAt = rows.lastIndex { $0.id == HomeRowKind.continueWatching.rawValue
                || $0.id == HomeRowKind.topRated.rawValue }
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

        // Featured heroes — highest TMDB rating first, then newest. The banner
        // resolves the real backdrop + synopsis from TMDB itself.
        let heroes: [HomeCard] = Array(moviesByRecency.prefix(150))
            .sorted { lhs, rhs in
                let l = ratings[lhs.id.rawValue] ?? 0, r = ratings[rhs.id.rawValue] ?? 0
                if l != r { return l > r }
                return (lhs.addedAt ?? .distantPast) > (rhs.addedAt ?? .distantPast)
            }
            .prefix(5)
            .map { movie in
                HomeCard(id: movie.id, kind: .movie, title: movie.title, subtitle: movie.synopsis,
                         artworkURL: movie.backdropURL ?? movie.posterURL,
                         year: movie.year, eyebrow: metadataSubtitle(for: movie))
            }

        let tonight = prefs.isRowEnabled(.tonight)
            ? buildTonight(channels: catalog.channels, epg: epg, now: now) : []

        return HomeContent(heroes: heroes, rows: rows.filter { !$0.cards.isEmpty }, tonight: tonight)
    }

    nonisolated private static func continueWatchingCards(catalog: Catalog, progress: [WatchProgress]) -> [HomeCard] {
        UpNext.resumePoints(catalog: catalog, progress: progress, limit: 12).map { point in
            HomeCard(id: point.containerID, kind: point.isSeries ? .series : .movie,
                     title: point.primaryTitle, subtitle: point.secondaryText,
                     artworkURL: point.artworkURL, progress: point.fraction > 0 ? point.fraction : nil,
                     resumeItemID: point.itemID)
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

    /// The newest movie / series the viewer has played that still carries genre
    /// tags — the anchor for the "Because You Watched" row.
    nonisolated static func mostRecentWatched(
        progress: [WatchProgress], catalog: Catalog
    ) -> (id: CatalogID, title: String, genres: [Genre])? {
        let moviesByID = Dictionary(catalog.movies.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var seriesByEpisode: [CatalogID: Series] = [:]
        for s in catalog.series {
            for season in s.seasons { for e in season.episodes { seriesByEpisode[e.id] = s } }
        }
        for entry in progress.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            switch entry.kind {
            case .movie:
                if let m = moviesByID[entry.itemID], !m.genres.isEmpty { return (m.id, m.title, m.genres) }
            case .series:
                if let s = seriesByEpisode[entry.itemID], !s.genres.isEmpty { return (s.id, s.title, s.genres) }
            case .liveChannel:
                break
            }
        }
        return nil
    }

    /// Movies + series that share a genre with `genres`, ranked by shared-genre
    /// count (ties keep the incoming recency order). Excludes the anchor itself.
    nonisolated static func similarTitles(
        toGenres genres: [Genre], excluding excludeID: CatalogID,
        movies: [Movie], series: [Series], limit: Int
    ) -> [HomeCard] {
        guard !genres.isEmpty else { return [] }
        let want = Set(genres)
        func overlap(_ g: [Genre]) -> Int { Set(g).intersection(want).count }

        var scored: [(card: HomeCard, score: Int)] = []
        for m in movies where m.id != excludeID {
            let o = overlap(m.genres); if o > 0 { scored.append((card(for: m), o)) }
        }
        for s in series where s.id != excludeID {
            let o = overlap(s.genres); if o > 0 { scored.append((card(for: s), o)) }
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map(\.card)
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
