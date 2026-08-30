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

    public init(repository: any CatalogRepository,
                watchProgress: WatchProgressStore,
                preferences: PreferencesStore) {
        self.repository = repository
        self.watchProgress = watchProgress
        self.preferences = preferences
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

        content = await Task.detached(priority: .userInitiated) {
            Self.makeContent(catalog: catalog, epg: epg, progress: progress, prefs: prefs, now: now)
        }.value
    }

    // MARK: - Pure builder (runs off the main actor)

    nonisolated static func makeContent(
        catalog: Catalog, epg: EPGIndex, progress: [WatchProgress],
        prefs: UserPreferences, now: Date
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

        add(.movies, "Movies", Array(moviesByRecency.prefix(30)).map { card(for: $0) })
        add(.series, "Series", Array(catalog.series.prefix(30)).map { card(for: $0) })

        // Match the user's preferred row order.
        rows.sort { lhs, rhs in
            (prefs.homeRows.firstIndex { $0.rawValue == lhs.id } ?? 99)
                < (prefs.homeRows.firstIndex { $0.rawValue == rhs.id } ?? 99)
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
                 subtitle: metadataSubtitle(for: movie), artworkURL: movie.posterURL)
    }

    nonisolated static func card(for series: Series) -> HomeCard {
        HomeCard(id: series.id, kind: .series, title: series.title,
                 subtitle: "\(series.seasons.count) season\(series.seasons.count == 1 ? "" : "s")",
                 artworkURL: series.posterURL)
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
