import Foundation

/// Where the user left off in a movie or episode.
public struct WatchProgress: Hashable, Codable, Sendable, Identifiable {
    public var id: CatalogID { itemID }
    public let itemID: CatalogID
    public let kind: ContentKind
    public let positionSeconds: Double
    public let durationSeconds: Double
    public let updatedAt: Date

    public init(
        itemID: CatalogID,
        kind: ContentKind,
        positionSeconds: Double,
        durationSeconds: Double,
        updatedAt: Date = .now
    ) {
        self.itemID = itemID
        self.kind = kind
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.updatedAt = updatedAt
    }

    public var fraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, max(0, positionSeconds / durationSeconds))
    }

    /// Considered "finished" past 95%, so it drops out of Continue Watching.
    public var isFinished: Bool { fraction >= 0.95 }

    public var isResumable: Bool { !isFinished && positionSeconds > 30 }
}

/// A favourited catalog item.
public struct Favorite: Hashable, Codable, Sendable, Identifiable {
    public var id: CatalogID { itemID }
    public let itemID: CatalogID
    public let kind: ContentKind
    public let addedAt: Date

    public init(itemID: CatalogID, kind: ContentKind, addedAt: Date = .now) {
        self.itemID = itemID
        self.kind = kind
        self.addedAt = addedAt
    }
}
