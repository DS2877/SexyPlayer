import Foundation

/// A single card's worth of data on the Home screen, kind-agnostic.
public struct HomeCard: Identifiable, Sendable {
    public enum Kind: Sendable { case movie, series, channel }

    public let id: CatalogID
    public let kind: Kind
    public let title: String
    public let subtitle: String?
    public let artworkURL: URL?
    public let badge: String?
    public let progress: Double?

    public init(id: CatalogID, kind: Kind, title: String, subtitle: String?, artworkURL: URL?, badge: String? = nil, progress: Double? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.badge = badge
        self.progress = progress
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
    public let time: String
    public let programTitle: String
    public let channelName: String
    public let isLiveNow: Bool
}

public struct HomeContent: Sendable {
    public var hero: HomeCard?
    public var rows: [HomeRow]
    public var tonight: [TonightItem]

    public static let empty = HomeContent(hero: nil, rows: [], tonight: [])
}
