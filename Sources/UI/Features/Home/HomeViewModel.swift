import Foundation
import Observation

@MainActor
@Observable
public final class HomeViewModel {

    public private(set) var content: HomeContent = .empty
    public private(set) var isBuilding = false

    private let repository: any CatalogRepository

    public init(repository: any CatalogRepository) {
        self.repository = repository
    }

    public func rebuild(now: Date = .now) async {
        isBuilding = true
        defer { isBuilding = false }

        let catalog = await repository.snapshot()
        guard !catalog.isEmpty else { content = .empty; return }

        var rows: [HomeRow] = []

        // Tonight (EPG-driven)
        let tonight = Self.buildTonight(from: catalog, now: now)

        // Live now
        let liveCards = catalog.channels.prefix(14).map { channel -> HomeCard in
            let currentEvent = catalog.nowPlaying(forEPGID: channel.epgID ?? "", at: now)
            return HomeCard(
                id: channel.id, kind: .channel,
                title: channel.name,
                subtitle: currentEvent?.title ?? channel.category,
                artworkURL: channel.logoURL,
                badge: currentEvent != nil ? "LIVE" : nil
            )
        }
        rows.append(HomeRow(id: "live", title: "Live Now", subtitle: nil, cards: Array(liveCards)))

        // Recently added
        let recent = catalog.movies.suffix(12).reversed().map { Self.card(for: $0) }
            + catalog.series.suffix(6).reversed().map { Self.card(for: $0) }
        rows.append(HomeRow(id: "recent", title: "Recently Added", subtitle: nil, cards: Array(recent.prefix(14))))

        // Movies
        rows.append(HomeRow(id: "movies", title: "Movies", subtitle: nil,
                            cards: catalog.movies.sorted { ($0.year ?? 0) > ($1.year ?? 0) }.map(Self.card(for:))))

        // Series
        rows.append(HomeRow(id: "series", title: "Series", subtitle: nil,
                            cards: catalog.series.map(Self.card(for:))))

        // Swedish content
        let swedish = catalog.movies.filter { $0.audioLanguages.contains(.swedish) }.map(Self.card(for:))
            + catalog.series.filter { $0.audioLanguages.contains(.swedish) }.map(Self.card(for:))
        rows.append(HomeRow(id: "swedish", title: "Swedish Content", subtitle: nil, cards: swedish))

        // With Swedish subtitles
        let swedishSubs = catalog.movies.filter { $0.subtitleLanguages.contains(.swedish) }.map(Self.card(for:))
            + catalog.series.filter { $0.subtitleLanguages.contains(.swedish) }.map(Self.card(for:))
        rows.append(HomeRow(id: "swesub", title: "With Swedish Subtitles", subtitle: nil, cards: swedishSubs))

        // Hero: newest high-quality movie
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
                         subtitle: movie.synopsis ?? Self.metadataSubtitle(for: movie),
                         artworkURL: movie.backdropURL ?? movie.posterURL)
            }

        content = HomeContent(
            hero: hero,
            rows: rows.filter { !$0.cards.isEmpty },
            tonight: tonight
        )
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
