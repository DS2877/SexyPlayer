import Foundation

/// Orchestrates the pure detectors to turn a `RawCatalog` into a domain
/// `Catalog`. Runs off the main actor; deterministic given the same input.
public struct Normalizer: Sendable {

    public init() {}

    public func normalize(_ raw: RawCatalog) -> Catalog {
        Catalog(
            channels: raw.channels.map { normalizeChannel($0, providerID: raw.providerID) },
            movies:   raw.vod.map { normalizeMovie($0, providerID: raw.providerID) },
            series:   normalizeSeries(raw.seriesEpisodes, providerID: raw.providerID),
            epg:      raw.epg.map(normalizeEPG)
        )
    }

    // MARK: - Channels

    func normalizeChannel(_ raw: RawChannel, providerID: String) -> Channel {
        let name = TitleNormalizer.channelName(raw.displayName)
        let langs = LanguageDetector.detect(name: raw.displayName, groupTitle: raw.groupTitle)
        let quality = QualityDetector.detect(in: [raw.displayName, raw.groupTitle])

        return Channel(
            id: CatalogID(providerID: providerID, kind: .liveChannel, providerItemKey: raw.providerKey),
            name: name,
            category: CategoryMapper.channelCategory(from: raw.groupTitle),
            logoURL: raw.logo.flatMap(URL.init(string:)),
            countryCode: CategoryMapper.countryCode(from: raw.displayName, groupTitle: raw.groupTitle),
            audioLanguages: langs.audio,
            subtitleLanguages: langs.subtitles,
            quality: quality,
            streamURL: URL(string: raw.streamURL) ?? Self.placeholderURL,
            epgID: raw.tvgID?.isEmpty == false ? raw.tvgID : nil,
            sortIndex: 0
        )
    }

    // MARK: - Movies

    func normalizeMovie(_ raw: RawVODItem, providerID: String) -> Movie {
        let (title, year) = TitleNormalizer.movieTitle(raw.name)
        let langs = LanguageDetector.detect(name: raw.name, groupTitle: raw.groupTitle)
        let genres = GenreDetector.detect(from: [raw.genreText, raw.groupTitle, raw.name])
        let quality = QualityDetector.detect(in: [raw.name, raw.groupTitle])

        return Movie(
            id: CatalogID(providerID: providerID, kind: .movie, providerItemKey: raw.providerKey),
            title: title,
            year: year ?? raw.releaseDate.flatMap(TitleNormalizer.extractYear),
            genres: genres,
            durationMinutes: raw.durationSecs.map { max(1, $0 / 60) },
            audioLanguages: langs.audio,
            subtitleLanguages: langs.subtitles,
            quality: quality,
            countryCode: CategoryMapper.countryCode(from: raw.name, groupTitle: raw.groupTitle),
            posterURL: raw.logo.flatMap(URL.init(string:)),
            backdropURL: nil,
            synopsis: raw.plot?.nonEmpty,
            cast: raw.cast?.splitList() ?? [],
            directors: raw.director?.splitList() ?? [],
            streamURL: URL(string: raw.streamURL) ?? Self.placeholderURL
        )
    }

    // MARK: - Series

    func normalizeSeries(_ rawEpisodes: [RawSeriesEpisode], providerID: String) -> [Series] {
        var grouped: [String: [(season: Int, episode: Int, raw: RawSeriesEpisode)]] = [:]
        var displayTitle: [String: String] = [:]

        for raw in rawEpisodes {
            let seriesTitle: String
            let season: Int
            let episode: Int

            if let name = raw.explicitSeriesName, let s = raw.explicitSeason, let e = raw.explicitEpisode {
                seriesTitle = name.collapsingWhitespace()
                season = s
                episode = e
            } else if let parsed = EpisodeParser.parse(TitleNormalizer.episodeRawName(raw.name)) {
                seriesTitle = parsed.seriesTitle
                season = parsed.season
                episode = parsed.episode
            } else {
                // Unparseable — treat as a single-episode "series" so it isn't lost.
                seriesTitle = TitleNormalizer.movieTitle(raw.name).title
                season = 1
                episode = 1
            }

            let key = seriesTitle.foldedForSearch()
            grouped[key, default: []].append((season, episode, raw))
            if displayTitle[key] == nil { displayTitle[key] = seriesTitle }
        }

        return grouped.map { key, entries in
            let title = displayTitle[key] ?? key
            let seriesID = CatalogID(providerID: providerID, kind: .series, providerItemKey: key)

            let bySeason = Dictionary(grouping: entries, by: { $0.season })
            let seasons = bySeason.keys.sorted().map { seasonNumber -> Season in
                let eps = bySeason[seasonNumber]!
                    .sorted { $0.episode < $1.episode }
                    .map { entry -> Episode in
                        Episode(
                            id: CatalogID(providerID: providerID, kind: .series,
                                          providerItemKey: "\(key)-s\(entry.season)e\(entry.episode)"),
                            seriesID: seriesID,
                            seasonNumber: entry.season,
                            episodeNumber: entry.episode,
                            title: episodeTitle(entry.raw.name, season: entry.season, episode: entry.episode),
                            overview: entry.raw.plot?.nonEmpty,
                            durationMinutes: nil,
                            stillURL: entry.raw.logo.flatMap(URL.init(string:)),
                            streamURL: URL(string: entry.raw.streamURL) ?? Self.placeholderURL
                        )
                    }
                return Season(seriesID: seriesID, number: seasonNumber, episodes: eps)
            }

            let allNames = entries.map { $0.raw.name }
            let allGroups = entries.compactMap { $0.raw.groupTitle }
            let langs = LanguageDetector.detect(
                name: allNames.joined(separator: " "),
                groupTitle: allGroups.joined(separator: " ")
            )

            return Series(
                id: seriesID,
                title: title,
                year: allNames.compactMap(TitleNormalizer.extractYear).min(),
                genres: GenreDetector.detect(from: allGroups.map { $0 as String? } + [title as String?]),
                audioLanguages: langs.audio,
                subtitleLanguages: langs.subtitles,
                quality: QualityDetector.detect(in: allNames.map { $0 as String? }),
                countryCode: nil,
                posterURL: entries.first?.raw.logo.flatMap(URL.init(string:)),
                backdropURL: nil,
                synopsis: entries.compactMap { $0.raw.plot?.nonEmpty }.first,
                seasons: seasons
            )
        }
        .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    private func episodeTitle(_ raw: String, season: Int, episode: Int) -> String {
        // Strip the leading "Series SxxExx" part if present, leaving any real
        // episode title behind.
        let cleaned = TitleNormalizer.episodeRawName(raw)
        let markerPattern = CompiledPattern(#"^.*?(?:s\d{1,2}[\s\-_.]*e\d{1,4}|\d{1,2}x\d{1,4}|season[\s\-_.]*\d{1,2}[\s\-_.]*episode[\s\-_.]*\d{1,4})[\s\-_.:]*"#)
        let remainder = markerPattern.removingMatches(in: cleaned).collapsingWhitespace()
        return remainder.isEmpty ? "Episode \(episode)" : remainder
    }

    // MARK: - EPG

    func normalizeEPG(_ raw: RawEPGEvent) -> EPGEvent {
        EPGEvent(
            channelEPGID: raw.channelID,
            title: raw.title.collapsingWhitespace(),
            subtitle: raw.subtitle?.nonEmpty,
            description: raw.description?.nonEmpty,
            start: raw.start,
            stop: raw.stop,
            category: raw.category?.nonEmpty
        )
    }

    static let placeholderURL = URL(string: "about:blank")!
}

// MARK: - Small helpers

private extension String {
    var nonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    func splitList() -> [String] {
        components(separatedBy: CharacterSet(charactersIn: ",;/"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
