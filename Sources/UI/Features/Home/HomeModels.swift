import Foundation

/// A single card's worth of data on the Home screen, kind-agnostic.
public struct HomeCard: Identifiable, Sendable {
    public enum Kind: Sendable { case movie, series, channel }

    public let id: CatalogID
    public let kind: Kind
    public let title: String
    public let subtitle: String?
    public let artworkURL: URL?
    public let year: Int?
    public let badge: String?
    public let progress: Double?
    /// How far through the current live programme a channel card is (0…1).
    public let liveProgress: Double?
    /// Small uppercase line above the title (hero only): "2024 · Sci-Fi · 4K".
    public let eyebrow: String?
    /// For Continue Watching cards: the item that actually plays / gets marked
    /// watched (an episode or movie id), distinct from `id` (the container the
    /// card taps through to). `nil` for every other card.
    public let resumeItemID: CatalogID?

    public init(id: CatalogID, kind: Kind, title: String, subtitle: String?, artworkURL: URL?, year: Int? = nil, badge: String? = nil, progress: Double? = nil, liveProgress: Double? = nil, eyebrow: String? = nil, resumeItemID: CatalogID? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.year = year
        self.badge = badge
        self.progress = progress
        self.liveProgress = liveProgress
        self.eyebrow = eyebrow
        self.resumeItemID = resumeItemID
    }

    /// A TMDB match reference for movie / series cards (nil for channels).
    public var artworkRef: ArtworkRef? {
        switch kind {
        case .movie:   return ArtworkRef(id: id, title: title, year: year, isSeries: false)
        case .series:  return ArtworkRef(id: id, title: title, year: year, isSeries: true)
        case .channel: return nil
        }
    }
}

public struct HomeRow: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let cards: [HomeCard]
}

public struct TonightItem: Identifiable, Sendable {
    public let id: String
    public let channelID: CatalogID
    public let time: String
    public let programTitle: String
    public let channelName: String
    public let isLiveNow: Bool
}

public struct HomeContent: Sendable {
    public var heroes: [HomeCard]
    public var rows: [HomeRow]
    public var tonight: [TonightItem]

    public var hero: HomeCard? { heroes.first }

    public static let empty = HomeContent(heroes: [], rows: [], tonight: [])
}
