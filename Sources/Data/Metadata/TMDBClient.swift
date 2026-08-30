import Foundation

/// Minimal client for The Movie Database (v3). Used to enrich the provider's
/// often-bare catalog with real artwork, synopses and ratings.
///
/// Privacy: each request sends only the title and year being matched — nothing
/// about the user, their provider, or what they watch. The key lives in the
/// Keychain and is only sent to api.themoviedb.org.
public struct TMDBClient: Sendable {

    public struct Match: Sendable, Equatable {
        public let tmdbID: Int
        public let posterURL: URL?
        public let backdropURL: URL?
        public let overview: String?
        public let rating: Double?      // vote_average, 0…10
        public let year: Int?
    }

    private let apiKey: String
    private let session: URLSession
    private let base = URL(string: "https://api.themoviedb.org/3/")!
    private static let posterBase = "https://image.tmdb.org/t/p/w500"
    private static let backdropBase = "https://image.tmdb.org/t/p/w1280"

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// A v4 "API Read Access Token" is a JWT (three dot-separated base64 parts);
    /// a v3 key isn't. They authenticate differently.
    private var isBearerToken: Bool {
        apiKey.hasPrefix("eyJ") && apiKey.split(separator: ".").count == 3
    }

    public func search(title: String, year: Int?, isSeries: Bool) async throws -> Match? {
        let path = isSeries ? "search/tv" : "search/movie"
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var query = [
            URLQueryItem(name: "query", value: title),
            URLQueryItem(name: "include_adult", value: "true"),
        ]
        if !isBearerToken {
            query.append(URLQueryItem(name: "api_key", value: apiKey))
        }
        if let year {
            query.append(URLQueryItem(name: isSeries ? "first_air_date_year" : "year", value: String(year)))
        }
        components.queryItems = query
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        if isBearerToken {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw TMDBError.badResponse(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard let best = Self.pick(decoded.results, title: title, year: year) else { return nil }

        return Match(
            tmdbID: best.id,
            posterURL: best.poster_path.flatMap { URL(string: Self.posterBase + $0) },
            backdropURL: best.backdrop_path.flatMap { URL(string: Self.backdropBase + $0) },
            overview: best.overview?.isEmpty == false ? best.overview : nil,
            rating: (best.vote_average ?? 0) > 0 ? best.vote_average : nil,
            year: Self.year(from: best.release_date ?? best.first_air_date)
        )
    }

    // MARK: - Matching

    private static func pick(_ results: [Result], title: String, year: Int?) -> Result? {
        guard !results.isEmpty else { return nil }
        let wanted = title.folded()
        func score(_ r: Result) -> Int {
            var s = 0
            let name = (r.title ?? r.name ?? "").folded()
            if name == wanted { s += 100 }
            else if name.hasPrefix(wanted) || wanted.hasPrefix(name) { s += 40 }
            if let year, let ry = self.year(from: r.release_date ?? r.first_air_date) {
                if ry == year { s += 30 } else if abs(ry - year) <= 1 { s += 12 }
            }
            s += min(Int((r.popularity ?? 0) / 5), 20)
            if r.poster_path != nil { s += 10 }
            return s
        }
        return results.max { score($0) < score($1) }
    }

    private static func year(from dateString: String?) -> Int? {
        guard let s = dateString, s.count >= 4 else { return nil }
        return Int(s.prefix(4))
    }

    // MARK: - DTOs

    private struct SearchResponse: Decodable { let results: [Result] }
    private struct Result: Decodable {
        let id: Int
        let title: String?
        let name: String?
        let overview: String?
        let poster_path: String?
        let backdrop_path: String?
        let vote_average: Double?
        let popularity: Double?
        let release_date: String?
        let first_air_date: String?
    }
}

public enum TMDBError: Error, Sendable {
    case badResponse(status: Int)
}

private extension String {
    func folded() -> String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
