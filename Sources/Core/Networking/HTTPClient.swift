import Foundation

/// Minimal async HTTP layer for provider adapters. Maps transport failures onto
/// `ProviderError` so raw `URLError`s never leak upward, and keeps request URLs
/// out of logs (they contain Xtream credentials).
public struct HTTPClient: @unchecked Sendable {  // URLSession is thread-safe

    public struct Config: Sendable {
        public var timeout: TimeInterval
        public var maxResponseBytes: Int
        public init(timeout: TimeInterval = 30, maxResponseBytes: Int = 200 * 1_024 * 1_024) {
            self.timeout = timeout
            self.maxResponseBytes = maxResponseBytes
        }
    }

    private let session: URLSession
    private let config: Config

    public init(config: Config = .init()) {
        self.config = config
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = config.timeout
        configuration.timeoutIntervalForResource = config.timeout * 4
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = ["User-Agent": "SexyPlayer/0.1 (tvOS)"]
        self.session = URLSession(configuration: configuration)
    }

    /// GET the URL and return the raw body. Throws `ProviderError`.
    public func data(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            try validate(response, data: data)
            return data
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.from(error)
        }
    }

    /// GET + JSON-decode. Xtream panels sometimes return `""` or `false` for
    /// "no content" — callers should tolerate `nil`.
    public func decode<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let data = try await self.data(from: url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            AppLog.provider.error("JSON decode failed for \(AppLog.redacting(url), privacy: .public)")
            throw ProviderError.badResponse
        }
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299:
            guard data.count <= config.maxResponseBytes else { throw ProviderError.badResponse }
        case 401, 403:
            throw ProviderError.authenticationFailed
        case 404, 400:
            throw ProviderError.badResponse
        case 408, 429, 500...599:
            throw ProviderError.cannotReachProvider
        default:
            throw ProviderError.badResponse
        }
    }
}
