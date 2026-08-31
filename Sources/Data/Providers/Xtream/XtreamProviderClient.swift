import Foundation

/// `ProviderClient` for an Xtream Codes account. Fetches live + VOD + series
/// shells in the bulk pass; series episodes load on demand.
public struct XtreamProviderClient: ProviderClient {

    public let descriptor: ProviderDescriptor
    private let api: XtreamAPI
    private let http: HTTPClient

    public init?(configuration: ProviderConfiguration, password: String, http: HTTPClient = .init()) {
        guard configuration.kind == .xtream,
              let host = configuration.xtreamHost,
              let username = configuration.xtreamUsername,
              let api = XtreamAPI(host: host, username: username, password: password)
        else { return nil }
        self.descriptor = configuration.descriptor
        self.api = api
        self.http = http
    }

    // MARK: - Bulk catalog

    public func fetchRawCatalog(progress: ImportProgressReporter) async throws -> RawCatalog {
        var channels: [RawChannel] = []
        var movies: [RawVODItem] = []
        var shells: [RawSeriesShell] = []
        var epg: [RawEPGEvent] = []
        try await fetchStaged(progress: progress) { stage in
            switch stage {
            case .channels(let c): channels = c
            case .vod(let m, let s, _): movies = m; shells = s
            case .guide(let e): epg = e
            }
        }
        return RawCatalog(providerID: descriptor.id, channels: channels, vod: movies,
                          seriesEpisodes: [], seriesShells: shells, epg: epg)
    }

    /// Staged: emit channels as soon as the live list lands (small, fast), then
    /// VOD + series, then the EPG (often the largest single request).
    public func fetchStaged(
        progress: ImportProgressReporter,
        emit: @Sendable (RawStage) async -> Void
    ) async throws {
        progress.reached(.connecting)
        try await verifyAuth()

        async let liveCatsF = categories(.liveCategories)
        async let vodCatsF = categories(.vodCategories)
        async let seriesCatsF = categories(.seriesCategories)
        async let liveRawF = fetch([XtreamDTO.LiveStream].self, .liveStreams)
        async let vodRawF = fetch([XtreamDTO.VODStream].self, .vodStreams)
        async let seriesRawF = fetch([XtreamDTO.SeriesListItem].self, .series)

        // Stage 1 — channels.
        let liveCategories = await liveCatsF
        let live = try await liveRawF
        let channels: [RawChannel] = live.enumerated().compactMap { index, s in
            guard let id = s.stream_id, let name = s.name else { return nil }
            return RawChannel(
                providerKey: String(id),
                displayName: name,
                groupTitle: liveCategories[s.category_id ?? ""],
                logo: s.stream_icon,
                tvgID: s.epg_channel_id,
                streamURL: api.liveStreamURL(id: id).absoluteString,
                channelNumber: s.num ?? (index + 1)
            )
        }
        progress.reached(.channels)
        await emit(.channels(channels))

        // Stage 2 — VOD + series shells.
        let (vodCategories, seriesCategories) = await (vodCatsF, seriesCatsF)
        let vod = try await vodRawF
        let movies: [RawVODItem] = vod.compactMap { v in
            guard let id = v.stream_id, let name = v.name else { return nil }
            return RawVODItem(
                providerKey: String(id),
                name: name,
                groupTitle: vodCategories[v.category_id ?? ""],
                logo: v.stream_icon,
                streamURL: api.vodStreamURL(id: id, extension: v.container_extension ?? "mp4").absoluteString,
                plot: v.plot,
                genreText: v.genre,
                releaseDate: v.releaseDate ?? v.added,
                durationSecs: v.episode_run_time.map { $0 * 60 },
                cast: v.cast,
                director: v.director,
                addedAt: Self.unixDate(v.added)
            )
        }
        progress.reached(.movies)
        // A missing/!broken series endpoint shouldn't sink the whole import.
        let series = (try? await seriesRawF) ?? []
        let shells: [RawSeriesShell] = series.compactMap { s in
            guard let id = s.series_id, let name = s.name else { return nil }
            return RawSeriesShell(
                providerKey: String(id),
                name: name,
                cover: s.cover,
                plot: s.plot,
                genreText: s.genre,
                cast: s.cast,
                director: s.director,
                releaseDate: s.releaseDate,
                groupTitle: seriesCategories[s.category_id ?? ""],
                addedAt: Self.unixDate(s.last_modified)
            )
        }
        progress.reached(.series)
        await emit(.vod(movies: movies, shells: shells, episodes: []))

        guard !channels.isEmpty || !movies.isEmpty || !shells.isEmpty else {
            AppLog.provider.error("Xtream import: authenticated but every list came back empty.")
            throw ProviderError.emptyLibrary
        }

        // Stage 3 — EPG.
        progress.reached(.guide)
        let epg = (try? await fetchEPG()) ?? []
        await emit(.guide(epg))

        AppLog.provider.info("Xtream import: \(channels.count) channels, \(movies.count) movies, \(shells.count) series.")
    }

    // MARK: - On demand

    public func fetchEpisodes(seriesKey: String) async throws -> [RawSeriesEpisode] {
        let info = try await http.decode(XtreamDTO.SeriesInfo.self, from: api.seriesInfoURL(seriesID: seriesKey))
        guard let episodesBySeason = info.episodes else { return [] }

        var result: [RawSeriesEpisode] = []
        for (seasonKey, episodes) in episodesBySeason {
            let seasonNumber = Int(seasonKey) ?? 1
            for ep in episodes {
                guard let epID = ep.id else { continue }
                result.append(RawSeriesEpisode(
                    providerKey: epID,
                    name: ep.title ?? "Episode \(ep.episode_num ?? 0)",
                    groupTitle: nil,
                    logo: ep.info?.movie_image,
                    streamURL: api.seriesStreamURL(episodeID: epID,
                                                   extension: ep.container_extension ?? "mp4").absoluteString,
                    plot: ep.info?.plot,
                    explicitSeriesName: nil,
                    explicitSeason: seasonNumber,
                    explicitEpisode: ep.episode_num ?? (result.count + 1)
                ))
            }
        }
        return result
    }

    public func resolveStreamURL(for _: String, kind _: ContentKind) async throws -> URL {
        // Xtream stream URLs are deterministic; the catalog already carries them.
        throw ProviderError.streamUnavailable
    }

    // MARK: - Helpers

    /// Xtream `added` / `last_modified` are unix-second strings.
    static func unixDate(_ string: String?) -> Date? {
        guard let string, let seconds = TimeInterval(string.trimmingCharacters(in: .whitespaces)), seconds > 0
        else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private func verifyAuth() async throws {
        let auth = try await http.decode(XtreamDTO.AuthResponse.self, from: api.authURL)
        guard let info = auth.user_info else { throw ProviderError.authenticationFailed }
        if let status = info.status?.lowercased(), status.contains("expired") || status.contains("banned") || status.contains("disabled") {
            throw ProviderError.authenticationFailed
        }
        if info.auth == "0" { throw ProviderError.authenticationFailed }
    }

    private func fetch<T: Decodable>(_ type: T.Type, _ action: XtreamAPI.Action) async throws -> T {
        try await http.decode(T.self, from: api.url(action))
    }

    private func categories(_ action: XtreamAPI.Action) async -> [String: String] {
        guard let list = try? await fetch([XtreamDTO.Category].self, action) else { return [:] }
        return Dictionary(list.compactMap { cat -> (String, String)? in
            guard let id = cat.category_id, let name = cat.category_name else { return nil }
            return (id, name)
        }, uniquingKeysWith: { a, _ in a })
    }

    private func fetchEPG() async throws -> [RawEPGEvent] {
        let data = try await http.data(from: api.xmltvURL)
        return try XMLTVParser.parse(data)
    }
}
