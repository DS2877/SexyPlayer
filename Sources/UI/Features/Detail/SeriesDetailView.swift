import SwiftUI

struct SeriesDetailView: View {
    let seriesID: CatalogID

    @Environment(AppEnvironment.self) private var env
    @State private var series: Series?
    @State private var notFound = false
    @State private var loadingEpisodes = false
    @State private var selectedSeason: Int?
    @State private var playback: PlaybackItem?
    @State private var enriched: EnrichedMetadata?
    @State private var related: [RelatedItem] = []
    @State private var episodeStills: [Int: URL] = [:]

    var body: some View {
        Group {
            if let series {
                loaded(series)
            } else if notFound {
                EmptyStateView(icon: "rectangle.stack", title: "Not available",
                               message: "This series isn't in your library anymore.")
            } else {
                ProgressView().controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: seriesID) { await load() }
        .onChange(of: env.catalogRevision) { _, _ in
            if series == nil { Task { await load() } }
        }
        .fullScreenCover(item: $playback) { item in
            PlayerScreen(
                item: item,
                preferredAudio: env.preferences.preferences.preferredAudioLanguages,
                preferredSubtitle: env.preferences.preferences.preferredSubtitleLanguage
            ) { id, kind, position, duration in
                env.recordProgress(id: id, kind: kind, position: position, duration: duration)
            }
        }
        .task(id: stillsKey) {
            guard let tmdbID = enriched?.tmdbID, tmdbID > 0, let season = selectedSeason else { return }
            episodeStills = await env.metadata.episodeStills(seriesTMDBID: tmdbID, season: season)
        }
        .onChange(of: playback) { previous, current in
            // Auto-play the next episode when one just finished.
            guard current == nil, let finished = previous,
                  env.preferences.preferences.autoPlayNextEpisode,
                  env.watchProgress.progress(for: finished.id)?.isFinished == true,
                  let series,
                  let next = nextEpisode(in: series, after: finished.id)
            else { return }
            playback = env.playback(forEpisode: next, seriesTitle: series.title)
        }
    }

    private func load() async {
        var found = await env.repository.series(id: seriesID)
        notFound = found == nil && env.catalogComplete
        if let loaded = found, !loaded.hasEpisodes {
            loadingEpisodes = true
            found = await env.ensureEpisodes(forSeries: seriesID)
            loadingEpisodes = false
        }
        series = found
        selectedSeason = resumeEpisode(in: found)?.seasonNumber ?? found?.seasons.first?.number
        guard let found else { return }
        related = await env.repository
            .similarSeries(to: found.id, genres: found.genres, limit: 18)
            .map { RelatedItem(id: $0.id, title: $0.title, year: $0.year,
                               posterURL: $0.posterURL, isSeries: true) }
        enriched = await env.metadata.details(
            for: found.id, title: found.title, year: found.year, isSeries: true
        )
    }

    /// The very first episode — first season by number, first episode by number.
    private func firstEpisode(in series: Series) -> Episode? {
        series.seasons
            .sorted { $0.number < $1.number }
            .compactMap { $0.episodes.min(by: { $0.episodeNumber < $1.episodeNumber }) }
            .first
    }

    private func nextEpisode(in series: Series, after episodeID: CatalogID) -> Episode? {
        let ordered = series.seasons
            .sorted { $0.number < $1.number }
            .flatMap { $0.episodes.sorted { $0.episodeNumber < $1.episodeNumber } }
        guard let idx = ordered.firstIndex(where: { $0.id == episodeID }), idx + 1 < ordered.count else {
            return nil
        }
        return ordered[idx + 1]
    }

    /// The most recently-watched, not-yet-finished episode of this series.
    private func resumeEpisode(in series: Series?) -> Episode? {
        guard let series else { return nil }
        return series.seasons
            .flatMap(\.episodes)
            .compactMap { ep -> (episode: Episode, watched: Date)? in
                guard let p = env.watchProgress.progress(for: ep.id), p.isResumable else { return nil }
                return (ep, p.updatedAt)
            }
            .max { $0.watched < $1.watched }?
            .episode
    }

    @ViewBuilder
    private func loaded(_ series: Series) -> some View {
        let season = series.seasons.first { $0.number == selectedSeason } ?? series.seasons.first

        let backdrop = series.backdropURL ?? enriched?.backdropURL ?? series.posterURL ?? enriched?.posterURL

        DetailScaffold(title: series.title, backdropURL: backdrop) {
            titleBlock(series)
            actions(series)
            info(series)
            if let credits = enriched?.castCredits, !credits.isEmpty {
                CastRail(credits: credits)
            }
            episodes(series, season: season)
            RelatedRail(title: "More Like This", items: related)
        }
    }

    // MARK: - Sections

    /// Poster thumbnail beside the title block — the Apple TV+ detail signature.
    @ViewBuilder
    private func titleBlock(_ series: Series) -> some View {
        HStack(alignment: .bottom, spacing: Metrics.space4) {
            EnrichedArtwork(
                ref: ArtworkRef(id: series.id, title: series.title, year: series.year, isSeries: true),
                providerURL: series.posterURL, aspect: 2.0 / 3.0, style: .poster
            )
            .frame(width: 220, height: 330)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
            .accessibilityHidden(true)

            header(series)
        }
    }

    @ViewBuilder
    private func header(_ series: Series) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            Text(series.title).font(.dsHero).tracking(Metrics.heroTracking).lineLimit(2)

            HStack(spacing: Metrics.space2) {
                if let rating = enriched?.rating {
                    TMDBRatingBadge(rating: rating, votes: enriched?.voteCount)
                }
                MetadataLine([
                    series.year.map(String.init),
                    series.genres.first?.displayName ?? enriched?.genres?.first,
                    "\(series.seasons.count) season\(series.seasons.count == 1 ? "" : "s")",
                    series.quality > .unknown ? series.quality.shortLabel : nil,
                ])
            }

            if let tagline = enriched?.tagline {
                Text(tagline)
                    .font(.dsBody.italic())
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func actions(_ series: Series) -> some View {
        HStack(spacing: Metrics.space2) {
            if let resume = resumeEpisode(in: series) {
                Button {
                    playback = env.playback(forEpisode: resume, seriesTitle: series.title)
                } label: {
                    Label("Resume \(resume.code)", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                if let first = firstEpisode(in: series), first.id != resume.id {
                    Button {
                        playback = env.playback(forEpisode: first, seriesTitle: series.title)
                    } label: {
                        Label("From Start", systemImage: "gobackward")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            } else if let first = firstEpisode(in: series) {
                Button {
                    playback = env.playback(forEpisode: first, seriesTitle: series.title)
                } label: {
                    Label("Play \(first.code)", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Button {
                env.favorites.toggle(id: series.id, kind: .series)
            } label: {
                Image(systemName: env.favorites.isFavorite(series.id) ? "heart.fill" : "heart")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel(env.favorites.isFavorite(series.id) ? "Remove from Favorites" : "Add to Favorites")
        }
    }

    @ViewBuilder
    private func info(_ series: Series) -> some View {
        let synopsis = series.synopsis ?? enriched?.overview
        let textCast = enriched?.cast ?? []
        let showTextCast = (enriched?.castCredits?.isEmpty ?? true) && !textCast.isEmpty

        VStack(alignment: .leading, spacing: Metrics.space2) {
            LanguageSummary(audio: series.audioLanguages, subtitles: series.subtitleLanguages)

            if let synopsis {
                Text(synopsis).font(.dsBody).foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: 1100, alignment: .leading)
            }

            if showTextCast {
                creditRow("Cast", textCast)
            }
        }
    }

    @ViewBuilder
    private func episodes(_ series: Series, season: Season?) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            if series.seasons.count > 1 {
                seasonPicker(series)
            }

            if loadingEpisodes {
                HStack(spacing: Metrics.space2) {
                    ProgressView().tint(Palette.accent)
                    Text("Loading episodes…").font(.dsCaption).foregroundStyle(Palette.textTertiary)
                }
            } else if series.seasons.isEmpty {
                Text("No episodes available for this series.")
                    .font(.dsCaption).foregroundStyle(Palette.textTertiary)
            }

            if let season {
                ForEach(season.episodes) { episode in
                    episodeRow(episode, seriesTitle: series.title)
                }
            }
        }
    }

    /// Refetch episode stills whenever the matched series or the visible season
    /// changes.
    private var stillsKey: String { "\(enriched?.tmdbID ?? 0)-\(selectedSeason ?? 0)" }

    private func creditRow(_ label: String, _ names: [String]) -> some View {
        HStack(alignment: .top, spacing: Metrics.space2) {
            Text(label).font(.dsCaption).foregroundStyle(Palette.textTertiary)
                .frame(width: 140, alignment: .leading)
            Text(names.joined(separator: ", "))
                .font(.dsCaption).foregroundStyle(Palette.textSecondary)
        }
    }

    private func seasonPicker(_ series: Series) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metrics.space1) {
                ForEach(series.seasons) { season in
                    FilterChip(
                        label: "Season \(season.number)",
                        isSelected: season.number == selectedSeason
                    ) {
                        selectedSeason = season.number
                    }
                }
            }
        }
        .focusSection()
    }

    private func episodeRow(_ episode: Episode, seriesTitle: String) -> some View {
        let progress = env.watchProgress.progress(for: episode.id)
        let still = episodeStills[episode.episodeNumber] ?? episode.stillURL

        let watched = progress?.isFinished == true

        return Button {
            playback = env.playback(forEpisode: episode, seriesTitle: seriesTitle)
        } label: {
            HStack(spacing: Metrics.space3) {
                ZStack {
                    ArtworkView(url: still, title: episode.title, aspect: 16.0 / 9.0, style: .backdrop)
                        .frame(width: 260, height: 146)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
                        .opacity(watched ? 0.55 : 1)
                    Image(systemName: watched ? "checkmark.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(watched ? Palette.accent : .white.opacity(0.92))
                        .shadow(radius: 8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(episode.code)  ·  \(episode.title)")
                        .font(.dsCardTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Metrics.space2) {
                        if let mins = episode.durationMinutes, mins > 0 {
                            Text("\(mins) min").font(.dsTag).foregroundStyle(Palette.textTertiary)
                        }
                        if watched {
                            Text("Watched").font(.dsTag).foregroundStyle(Palette.accent)
                        }
                    }

                    if let overview = episode.overview {
                        Text(overview)
                            .font(.dsCaption)
                            .foregroundStyle(Palette.textTertiary)
                            .lineLimit(2)
                    }
                    if let progress, progress.isResumable {
                        ProgressView(value: progress.fraction)
                            .tint(Palette.accent)
                            .frame(maxWidth: 320)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityLabel("\(episode.code), \(episode.title)\(watched ? ", watched" : "")")
    }
}
