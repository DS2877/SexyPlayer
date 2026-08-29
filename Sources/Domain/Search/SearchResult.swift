import Foundation

/// One hit from a catalog search, with the score that ranked it.
public struct SearchResult: Identifiable, Sendable {
    public enum Item: Sendable {
        case movie(Movie)
        case series(Series)
        case channel(Channel)
    }

    public let item: Item
    public let score: Double

    public var id: CatalogID {
        switch item {
        case .movie(let m):   return m.id
        case .series(let s):  return s.id
        case .channel(let c): return c.id
        }
    }

    public var title: String {
        switch item {
        case .movie(let m):   return m.title
        case .series(let s):  return s.title
        case .channel(let c): return c.name
        }
    }

    public var kind: ContentKind {
        switch item {
        case .movie:   return .movie
        case .series:  return .series
        case .channel: return .liveChannel
        }
    }

    public init(item: Item, score: Double) {
        self.item = item
        self.score = score
    }
}
