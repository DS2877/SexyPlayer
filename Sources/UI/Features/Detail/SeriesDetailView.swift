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
            selectedSeason = series?.seasons.first?.number
        }
        .fullScreenCover(item: $playback) { item in
            PlayerScreen(item: item) { id, kind, position, duration in
                env.recordProgress(id: id, kind: kind, position: position, duration: duration)
            }
        }
    }

    @ViewBuilder
    private func loaded(_ series: Series) -> some View {
        let season = series.seasons.first { $0.number == selectedSeason } ?? series.seasons.first

        DetailScaffold(title: series.title, backdropURL: series.backdropURL ?? series.posterURL) {
            Text(series.title).font(.dsHero).lineLimit(2)

            MetadataLine([
                series.year.map(String.init),
                series.genres.first?.displayName,
                "\(series.seasons.count) season\(series.seasons.count == 1 ? "" : "s")",
                series.quality > .unknown ? series.quality.shortLabel : nil,
            ])

            HStack(spacing: Metrics.space2) {
                Button {
                    env.favorites.toggle(id: series.id, kind: .series)
                } label: {
                    Label(env.favorites.isFavorite(series.id) ? "In Favorites" : "Add to Favorites",
                          systemImage: env.favorites.isFavorite(series.id) ? "heart.fill" : "heart")
                        .font(.dsCaption)
                        .padding(.horizontal, Metrics.space2)
                        .padding(.vertical, Metrics.space1)
                }
                .buttonStyle(.bordered)
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
                    ArtworkView(url: episode.stillURL, title: episode.title, aspect: 16.0 / 9.0)
                        .frame(width: 320, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.9))
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
                            .frame(width: 320)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Metrics.space2)
        }
        .buttonStyle(.card)
    }
}
