import Foundation

/// The vocabulary a parser is allowed to resolve against — derived from the
/// user's own library. This is the *only* library-derived data sent to a remote
/// LLM, and it contains no titles, credentials, or URLs.
public struct SearchVocabulary: Sendable, Equatable {
    public var genres: [Genre]
    public var audioLanguages: [Language]
    public var subtitleLanguages: [Language]
    public var hasMovies: Bool
    public var hasSeries: Bool
    public var hasLiveTV: Bool

    public init(
        genres: [Genre] = Genre.allCases,
        audioLanguages: [Language] = [],
        subtitleLanguages: [Language] = [],
        hasMovies: Bool = true,
        hasSeries: Bool = true,
        hasLiveTV: Bool = true
    ) {
        self.genres = genres
        self.audioLanguages = audioLanguages
        self.subtitleLanguages = subtitleLanguages
        self.hasMovies = hasMovies
        self.hasSeries = hasSeries
        self.hasLiveTV = hasLiveTV
    }

    public static func from(catalog: Catalog) -> SearchVocabulary {
        SearchVocabulary(
            genres: Array(Set(catalog.movies.flatMap(\.genres) + catalog.series.flatMap(\.genres))).sorted { $0.rawValue < $1.rawValue },
            audioLanguages: Array(Set(catalog.movies.flatMap(\.audioLanguages) + catalog.series.flatMap(\.audioLanguages))).sorted(),
            subtitleLanguages: Array(Set(catalog.movies.flatMap(\.subtitleLanguages) + catalog.series.flatMap(\.subtitleLanguages))).sorted(),
            hasMovies: !catalog.movies.isEmpty,
            hasSeries: !catalog.series.isEmpty,
            hasLiveTV: !catalog.channels.isEmpty
        )
    }
}

/// Turns a natural-language string into a `SearchIntent`. Implementations:
///   - `DeterministicQueryParser` — on-device, no network (always available).
///   - `ClaudeQueryParser` — remote LLM for fuzzy queries (M4, opt-in).
public protocol AIQueryParser: Sendable {
    func parse(_ query: String, vocabulary: SearchVocabulary) async throws -> SearchIntent
}

public enum AIQueryParserError: Error, Sendable {
    case empty
    case providerUnavailable
    case malformedResponse
}
