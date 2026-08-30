import Foundation

public enum BrowseKind: Sendable {
    case movies
    case series

    var title: String {
        switch self {
        case .movies: return "Movies"
        case .series: return "Series"
        }
    }
}

/// A card in a browse grid — kind-agnostic.
public struct BrowseCard: Identifiable, Sendable {
    public let id: CatalogID
    public let route: AppRoute
    public let title: String
    public let subtitle: String?
    public let posterURL: URL?
    public let progress: Double?
    public let year: Int?
    public let isSeries: Bool

    public var artworkRef: ArtworkRef {
        ArtworkRef(id: id, title: title, year: year, isSeries: isSeries)
    }
}

extension BrowseCard {
    init(movie: Movie, progress: Double?) {
        self.init(
            id: movie.id,
            route: .movie(movie.id),
            title: movie.title,
            subtitle: [movie.year.map(String.init), movie.genres.first?.displayName]
                .compactMap { $0 }.joined(separator: " · ").nilIfBlank,
            posterURL: movie.posterURL,
            progress: progress,
            year: movie.year,
            isSeries: false
        )
    }

    init(series: Series) {
        self.init(
            id: series.id,
            route: .series(series.id),
            title: series.title,
            subtitle: [series.year.map(String.init), series.genres.first?.displayName]
                .compactMap { $0 }.joined(separator: " · ").nilIfBlank,
            posterURL: series.posterURL,
            progress: nil,
            year: series.year,
            isSeries: true
        )
    }
}

private extension String {
    var nilIfBlank: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
}
