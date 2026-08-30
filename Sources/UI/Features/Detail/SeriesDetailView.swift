import SwiftUI

struct SeriesDetailView: View {
    let seriesID: CatalogID

    @Environment(AppEnvironment.self) private var env
    @State private var series: Series?
    @State private var notFound = false
    @State private var loadingEpisodes = false
    @State private var selectedSeason: Int?
    @State private var playback: PlaybackItem?

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
        .task(id: seriesID) {
            series = await env.repository.series(id: seriesID)
            notFound = series == nil
            if let loaded = series, !loaded.hasEpisodes {
                loadingEpisodes = true
                series = await env.ensureEpisodes(forSeries: seriesID)
                loadingEpisodes = false
            }
            // Jump to the season of an in-progress episode, else the first.
            selectedSeason = resumeEpisode(in: series)?.seasonNumber
                ?? series?.seasons.first?.number
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

        DetailScaffold(title: series.title, backdropURL: series.backdropURL ?? series.posterURL) {
            Text(series.title).font(.dsHero).tracking(Metrics.heroTracking).lineLimit(2)

            MetadataLine([
                series.year.map(String.init),
                series.genres.first?.displayName,
                "\(series.seasons.count) season\(series.seasons.count == 1 ? "" : "s")",
                series.quality > .unknown ? series.quality.shortLabel : nil,
            ])

            HStack(spacing: Metrics.space2) {
                if let resume = resumeEpisode(in: series) {
                    Button {
                        playback = env.playback(forEpisode: resume, seriesTitle: series.title)
                    } label: {
                        Label("Resume \(resume.code)", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button {
                    env.favorites.toggle(id: series.id, kind: .series)
                } label: {
                    Label(env.favorites.isFavorite(series.id) ? "In Favorites" : "Add to Favorites",
                          systemImage: env.favorites.isFavorite(series.id) ? "heart.fill" : "heart")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            LanguageSummary(audio: series.audioLanguages, subtitles: series.subtitleLanguages)

            if let synopsis = series.synopsis {
                Text(synopsis).font(.dsBody).foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: 1100, alignment: .leading)
            }

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
                VStack(alignment: .leading, spacing: Metrics.space2) {
                    ForEach(season.episodes) { episode in
                        episodeRow(episode, seriesTitle: series.title)
                    }
                }
            }
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

        return Button {
            playback = env.playback(forEpisode: episode, seriesTitle: seriesTitle)
        } label: {
            HStack(spacing: Metrics.space3) {
                ZStack {
                    ArtworkView(url: episode.stillURL, title: episode.title, aspect: 16.0 / 9.0, style: .backdrop)
                        .frame(width: 260, height: 146)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(radius: 8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(episode.code)  ·  \(episode.title)")
                        .font(.dsCardTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
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
    }
}
