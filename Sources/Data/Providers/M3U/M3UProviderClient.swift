import Foundation

/// `ProviderClient` for a plain M3U/M3U8 playlist URL, optionally paired with an
/// XMLTV EPG URL. The playlist URL frequently embeds credentials, so it is only
/// ever read from the Keychain and never logged in full.
public struct M3UProviderClient: ProviderClient {

    public let descriptor: ProviderDescriptor
    private let playlistURL: URL
    private let epgURL: URL?
    private let http: HTTPClient

    public init?(configuration: ProviderConfiguration, playlistURLString: String, epgURLString: String?, http: HTTPClient = .init()) {
        guard configuration.kind == .m3u,
              let playlistURL = URL(string: playlistURLString.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        self.descriptor = configuration.descriptor
        self.playlistURL = playlistURL
        self.epgURL = epgURLString.flatMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        self.http = http
    }

    public func fetchRawCatalog(progress: ImportProgressReporter) async throws -> RawCatalog {
        progress.reached(.connecting)
        let data = try await http.data(from: playlistURL)
        var catalog = try M3UParser.parse(data, providerID: descriptor.id)
        progress.reached(.channels)
        progress.reached(.movies)
        progress.reached(.series)

        progress.reached(.guide)
        if let epgURL {
            if let epgData = try? await http.data(from: epgURL),
               let events = try? XMLTVParser.parse(epgData) {
                catalog.epg = events
            }
        }
        AppLog.provider.info("M3U import: \(catalog.channels.count) channels, \(catalog.vod.count) movies, \(catalog.seriesEpisodes.count) episodes.")
        return catalog
    }

    public func resolveStreamURL(for providerItemKey: String, kind _: ContentKind) async throws -> URL {
        guard let url = URL(string: providerItemKey) else { throw ProviderError.streamUnavailable }
        return url
    }
}
