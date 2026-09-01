import Foundation
import Observation

@MainActor
@Observable
public final class HomeViewModel {

    public private(set) var content: HomeContent = .empty
    public private(set) var isBuilding = false

    private let repository: any CatalogQuerying
    private let watchProgress: WatchProgressStore
    private let preferences: PreferencesStore
    private let metadata: MetadataService
    private let channelHistory: ChannelHistoryStore

    /// During a staged import the catalog + metadata revisions bump many times a
    /// second. Without coalescing, every bump spawns another full-catalog shaping
    /// pass; a handful running at once is enough to jetsam the app on device.
    private var pendingRebuild: Task<Void, Never>?

    public init(repository: any CatalogQuerying,
                watchProgress: WatchProgressStore,
                preferences: PreferencesStore,
                metadata: MetadataService,
                channelHistory: ChannelHistoryStore) {
        self.repository = repository
        self.watchProgress = watchProgress
        self.preferences = preferences
        self.metadata = metadata
        self.channelHistory = channelHistory
    }

    /// Coalesced: rapid callers (import revisions, preference changes) collapse
    /// into a single shaping pass ~300 ms after the last trigger. Only one runs
    /// at a time.
    public func rebuild(now: Date = .now) async {
        pendingRebuild?.cancel()
        let task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            await self.performRebuild(now: now)
        }
        pendingRebuild = task
        await task.value
    }

    /// How much of the library each shelf query pulls. These bound Home's
    /// working set to a few thousand rows regardless of library size — the whole
    /// reason for the SQLite store.
    private enum Slice {
        static let newestMovies = 500
        static let newestSeries = 200
        static let perGenreMovies = 24
        static let perGenreSeries = 10
        static let topGenres = 6
        static let languageShelf = 30
        static let guideChannels = 60
    }

    private func performRebuild(now: Date) async {
        isBuilding = true
        defer { isBuilding = false }

        let prefs = preferences.preferences
        let progress = watchProgress.allEntries()

        guard await repository.isReady() else { content = .empty; return }
        guard !Task.isCancelled else { return }

        // Bounded shelf queries — never the whole catalog.
        async let newestMoviesF = repository.newestMovies(limit: Slice.newestMovies)
        async let newestSeriesF = repository.newestSeries(limit: Slice.newestSeries)
        async let liveNowF = repository.channels(in: nil, sort: .number, page: 0, pageSize: 18)
        async let guideChannelsF = repository.guideChannels(limit: Slice.guideChannels)
        async let ratingsF = metadata.ratingsSnapshot()

        var newestMovies = await newestMoviesF
        var newestSeries = await newestSeriesF
        let liveNow = await liveNowF
        let guideChannels = await guideChannelsF
        let ratings = await ratingsF
        guard !Task.isCancelled else { return }

        // Resolve the containers Continue Watching / "Because You Watched" need.
        let watchedMovies = await repository.movies(ids: progress.filter { $0.kind == .movie }.map(\.itemID))
        var watchedEpisodes: [Episode] = []
        for id in progress.filter({ $0.kind == .series }).map(\.itemID) {
            if let episode = await repository.episode(id: id) { watchedEpisodes.append(episode) }
        }
        let watchedSeries = await repository.series(ids: Array(Set(watchedEpisodes.map(\.seriesID))))
        guard !Task.isCancelled else { return }

        // Genre shelves.
        let topGenres = await repository.topGenres(limit: Slice.topGenres)
        var genreMovies: [Movie] = []
        var genreSeries: [Series] = []
        for genre in topGenres {
            genreMovies += await repository.moviesInGenre(genre, limit: Slice.perGenreMovies)
            genreSeries += await repository.seriesInGenre(genre, limit: Slice.perGenreSeries)
        }
        guard !Task.isCancelled else { return }

        // Language shelves.
        let langMovies = prefs.preferredAudioLanguages.isEmpty ? []
            : await repository.moviesInAudioLanguages(prefs.preferredAudioLanguages, limit: Slice.languageShelf)
        let subMovies: [Movie]
        if let sub = prefs.preferredSubtitleLanguage {
            subMovies = await repository.moviesInSubtitleLanguage(sub, limit: Slice.languageShelf)
        } else {
            subMovies = []
        }
        guard !Task.isCancelled else { return }

        // "Because You Watched" — genre-similar to the newest played title.
        // `watchedSeries` already carries its season tree from the store.
        var becauseMovies: [Movie] = []
        var becauseSeries: [Series] = []
        if let anchor = Self.mostRecentWatched(
            progress: progress, catalog: Catalog(movies: watchedMovies, series: watchedSeries)
        ) {
            becauseMovies = await repository.similarMovies(to: anchor.id, genres: anchor.genres, limit: 20)
            becauseSeries = await repository.similarSeries(to: anchor.id, genres: anchor.genres, limit: 12)
        }
        guard !Task.isCancelled else { return }

        // Merge into one bounded catalog for the shaper, de-duplicated.
        newestMovies = Self.uniqued(newestMovies + watchedMovies + genreMovies + langMovies + subMovies + becauseMovies)
        newestSeries = Self.uniqued(newestSeries + watchedSeries + genreSeries + becauseSeries)
        let channels = Self.uniqued(liveNow + guideChannels)

        let window = DateInterval(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(18 * 3600))
        let epg = await repository.epgIndex(forEPGIDs: channels.compactMap(\.epgID), in: window)
        guard !Task.isCancelled else { return }

        let miniCatalog = Catalog(channels: channels, movies: newestMovies, series: newestSeries,
                                  epg: epg.values.flatMap { $0 })
        let recentChannelIDs = channelHistory.recent(limit: 16)

        content = Self.makeContent(catalog: miniCatalog, epg: epg, progress: progress,
                                   prefs: prefs, ratings: ratings, liveNow: liveNow,
                                   recentChannelIDs: recentChannelIDs, now: now)
    }

    /// De-dupe by id, keeping first-seen order.
    nonisolated private static func uniqued<T: Identifiable>(_ items: [T]) -> [T] where T.ID: Hashable {
        var seen = Set<T.ID>()
        return items.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Pure builder (runs off the main actor)

    nonisolated static func makeContent(
        catalog: Catalog, epg: EPGIndex, progress: [WatchProgress],
        prefs: UserPreferences, ratings: [String: Double], liveNow: [Channel],
        recentChannelIDs: [CatalogID] = [], now: Date
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

        let liveCards = liveNow.prefix(16).map { channelCard($0, epg: epg, now: now) }
        add(.liveNow, "Live Now", Array(liveCards))

        // "Recently Watched" live channels — the viewer's own tune-in history.
        let recentChannelRow: HomeRow? = {
            guard !recentChannelIDs.isEmpty else { return nil }
            let byID = Dictionary(catalog.channels.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let cards = recentChannelIDs.compactMap { byID[$0] }.map { channelCard($0, epg: epg, now: now) }
            guard cards.count >= 2 else { return nil }
            return HomeRow(id: "recent-channels", title: "Recently Watched", subtitle: nil, cards: cards)
        }()

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
        if let recentChannelRow { rows.append(recentChannelRow) }

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

        // Float the position-less rows up just below Continue Watching, in a
        // deliberate order: Top Rated, Because You Watched, Recently Watched.
        var floatIDs = [HomeRowKind.topRated.rawValue]
        if let becauseID = becauseRow?.id { floatIDs.append(becauseID) }
        if let recentID = recentChannelRow?.id { floatIDs.append(recentID) }
        var placedFloats: Set<String> = []
        for floatID in floatIDs {
            guard let idx = rows.firstIndex(where: { $0.id == floatID }) else { continue }
            let row = rows.remove(at: idx)
            let insertAt = rows.lastIndex { $0.id == HomeRowKind.continueWatching.rawValue
                || placedFloats.contains($0.id) }
                .map { $0 + 1 } ?? 0
            rows.insert(row, at: Swift.min(insertAt, rows.count))
            placedFloats.insert(floatID)
        }

        // Genre shelves sit just above the generic Movies / Series shelves.
        if !genreRows.isEmpty {
            let anchor = rows.firstIndex {
                $0.id == HomeRowKind.movies.rawValue || $0.id == HomeRowKind.series.rawValue
            } ?? rows.count
            rows.insert(contentsOf: genreRows, at: anchor)
        }

        // Featured heroes — highest TMDB rating first, then newest, drawn from
        // both movies and series. The banner resolves the real backdrop +
        // synopsis from TMDB itself.
        let heroMovies: [(card: HomeCard, score: Double, added: Date)] =
            moviesByRecency.prefix(120).map { m in
                (card: HomeCard(id: m.id, kind: .movie, title: m.title, subtitle: m.synopsis,
                                artworkURL: m.backdropURL ?? m.posterURL, year: m.year,
                                eyebrow: metadataSubtitle(for: m)),
                 score: ratings[m.id.rawValue] ?? 0,
                 added: m.addedAt ?? .distantPast)
            }
        let heroSeries: [(card: HomeCard, score: Double, added: Date)] =
            seriesByRecency.prefix(40).map { s in
                (card: HomeCard(id: s.id, kind: .series, title: s.title, subtitle: s.synopsis,
                                artworkURL: s.backdropURL ?? s.posterURL, year: s.year,
                                eyebrow: heroEyebrow(for: s)),
                 score: ratings[s.id.rawValue] ?? 0,
                 added: s.addedAt ?? .distantPast)
            }
        let heroPool = heroMovies + heroSeries
        let heroes: [HomeCard] = heroPool
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.added > rhs.added
            }
            .prefix(5)
            .map(\.card)

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

    nonisolated static func channelCard(_ channel: Channel, epg: EPGIndex, now: Date) -> HomeCard {
        let event = channel.epgID.flatMap { epg.nowPlaying(forChannel: $0, at: now) }
        return HomeCard(id: channel.id, kind: .channel, title: channel.name,
                        subtitle: event?.title ?? channel.category,
                        artworkURL: channel.logoURL, badge: event != nil ? "LIVE" : nil,
                        liveProgress: event?.progress(at: now))
    }

    nonisolated static func card(for series: Series) -> HomeCard {
        // Shelf series come from the store without their season tree loaded;
        // fall back to year / genre when the count isn't known.
        let subtitle: String
        if series.seasons.isEmpty {
            subtitle = [series.year.map(String.init), series.genres.first?.displayName]
                .compactMap { $0 }.joined(separator: " · ")
        } else {
            subtitle = "\(series.seasons.count) season\(series.seasons.count == 1 ? "" : "s")"
        }
        return HomeCard(id: series.id, kind: .series, title: series.title,
                        subtitle: subtitle, artworkURL: series.posterURL, year: series.year)
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
                if let m = moviesByID[entry.itemID], !m.genres.isEmpty {
                    return (id: m.id, title: m.title, genres: m.genres)
                }
            case .series:
                if let s = seriesByEpisode[entry.itemID], !s.genres.isEmpty {
                    return (id: s.id, title: s.title, genres: s.genres)
                }
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
            let o = overlap(m.genres); if o > 0 { scored.append((card: card(for: m), score: o)) }
        }
        for s in series where s.id != excludeID {
            let o = overlap(s.genres); if o > 0 { scored.append((card: card(for: s), score: o)) }
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map(\.card)
    }

    nonisolated static func heroEyebrow(for series: Series) -> String {
        var parts: [String] = []
        if let year = series.year { parts.append(String(year)) }
        if let genre = series.genres.first { parts.append(genre.displayName) }
        if !series.seasons.isEmpty {
            parts.append("\(series.seasons.count) season\(series.seasons.count == 1 ? "" : "s")")
        }
        if series.quality > .unknown { parts.append(series.quality.shortLabel) }
        return parts.joined(separator: " · ")
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
