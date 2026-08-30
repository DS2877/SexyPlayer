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

        let catalog = await repository.snapshot()
        guard !catalog.isEmpty else { content = .empty; return }

        let prefs = preferences.preferences
        let enabled = Set(prefs.homeRows)
        var rows: [HomeRow] = []

        let tonight = prefs.isRowEnabled(.tonight) ? Self.buildTonight(from: catalog, now: now) : []

        func add(_ kind: HomeRowKind, _ title: String, _ cards: [HomeCard], subtitle: String? = nil) {
            guard enabled.contains(kind) else { return }
            rows.append(HomeRow(id: kind.rawValue, title: title, subtitle: subtitle, cards: cards))
        }

        add(.continueWatching, "Continue Watching", continueWatchingCards(catalog: catalog))

        let liveCards = catalog.channels.prefix(16).map { channel -> HomeCard in
            let currentEvent = catalog.nowPlaying(forEPGID: channel.epgID ?? "", at: now)
            return HomeCard(
                id: channel.id, kind: .channel,
                title: channel.name,
                subtitle: currentEvent?.title ?? channel.category,
                artworkURL: channel.logoURL,
                badge: currentEvent != nil ? "LIVE" : nil
            )
        }
        add(.liveNow, "Live Now", Array(liveCards))

        let recent = catalog.movies.suffix(12).reversed().map { Self.card(for: $0) }
            + catalog.series.suffix(6).reversed().map { Self.card(for: $0) }
        add(.recentlyAdded, "Recently Added", Array(recent.prefix(16)))

        // In your languages
        if !prefs.preferredAudioLanguages.isEmpty {
            let want = Set(prefs.preferredAudioLanguages)
            let cards = catalog.movies.filter { !Set($0.audioLanguages).isDisjoint(with: want) }.prefix(20).map(Self.card(for:))
                + catalog.series.filter { !Set($0.audioLanguages).isDisjoint(with: want) }.prefix(10).map(Self.card(for:))
            add(.inYourLanguages, "In Your Languages", Array(cards))
        }

        // With your subtitles
        if let sub = prefs.preferredSubtitleLanguage {
            let cards = catalog.movies.filter { $0.subtitleLanguages.contains(sub) }.prefix(20).map(Self.card(for:))
                + catalog.series.filter { $0.subtitleLanguages.contains(sub) }.prefix(10).map(Self.card(for:))
            add(.withYourSubtitles, "With \(sub.displayName) Subtitles", Array(cards))
        }

        add(.movies, "Movies",
            catalog.movies.sorted { ($0.year ?? 0) > ($1.year ?? 0) }.prefix(30).map(Self.card(for:)))
        add(.series, "Series", catalog.series.prefix(30).map(Self.card(for:)))

        // Order rows to match the user's preference order.
        rows.sort { lhs, rhs in
            (prefs.homeRows.firstIndex { $0.rawValue == lhs.id } ?? 99)
                < (prefs.homeRows.firstIndex { $0.rawValue == rhs.id } ?? 99)
        }

        let hero = catalog.movies
            .sorted { lhs, rhs in
                let ly = lhs.year ?? 0, ry = rhs.year ?? 0
                if ly != ry { return ly > ry }
                return lhs.quality > rhs.quality
            }
            .first
            .map { movie in
                HomeCard(id: movie.id, kind: .movie,
                         title: movie.title,
                         subtitle: movie.synopsis,
                         artworkURL: movie.backdropURL ?? movie.posterURL,
                         eyebrow: Self.metadataSubtitle(for: movie))
            }

        content = HomeContent(
            hero: hero,
            rows: rows.filter { !$0.cards.isEmpty },
            tonight: tonight
        )
    }

    // MARK: - Continue Watching

    private func continueWatchingCards(catalog: Catalog) -> [HomeCard] {
        UpNext.resumePoints(catalog: catalog, progress: watchProgress.allEntries(), limit: 12)
            .map { point in
                HomeCard(
                    id: point.containerID,
                    kind: point.isSeries ? .series : .movie,
                    title: point.primaryTitle,
                    subtitle: point.secondaryText,
                    artworkURL: point.artworkURL,
                    progress: point.fraction > 0 ? point.fraction : nil
                )
            }
    }

    // MARK: - Builders

    static func buildTonight(from catalog: Catalog, now: Date) -> [TonightItem] {
        let cal = Calendar(identifier: .gregorian)
        let endWindow = cal.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? now
        let window = DateInterval(start: now, end: max(now, endWindow))

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        var items: [TonightItem] = []
        for channel in catalog.channels {
            guard let epgID = channel.epgID else { continue }
            let events = catalog.events(forEPGID: epgID, in: window).prefix(3)
            for event in events {
                items.append(TonightItem(
                    id: event.id,
                    channelID: channel.id,
                    time: formatter.string(from: event.start),
                    programTitle: event.title,
                    channelName: channel.name,
                    isLiveNow: event.isLive(at: now)
                ))
            }
        }
        return Array(items.sorted { $0.time < $1.time }.prefix(12))
    }

    static func card(for movie: Movie) -> HomeCard {
        HomeCard(id: movie.id, kind: .movie,
                 title: movie.title,
                 subtitle: metadataSubtitle(for: movie),
                 artworkURL: movie.posterURL)
    }

    static func card(for series: Series) -> HomeCard {
        HomeCard(id: series.id, kind: .series,
                 title: series.title,
                 subtitle: "\(series.seasons.count) season\(series.seasons.count == 1 ? "" : "s")",
                 artworkURL: series.posterURL)
    }

    static func metadataSubtitle(for movie: Movie) -> String {
        var parts: [String] = []
        if let year = movie.year { parts.append(String(year)) }
        if let genre = movie.genres.first { parts.append(genre.displayName) }
        if let d = movie.durationMinutes { parts.append("\(d / 60)h \(d % 60)m") }
        if movie.quality > .unknown { parts.append(movie.quality.shortLabel) }
        return parts.joined(separator: " · ")
    }
}
