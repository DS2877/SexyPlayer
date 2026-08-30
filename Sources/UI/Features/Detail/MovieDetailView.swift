import SwiftUI

struct MovieDetailView: View {
    let movieID: CatalogID

    @Environment(AppEnvironment.self) private var env
    @State private var movie: Movie?
    @State private var notFound = false
    @State private var playback: PlaybackItem?
    @State private var enriched: EnrichedMetadata?

    var body: some View {
        Group {
            if let movie {
                loaded(movie)
            } else if notFound {
                EmptyStateView(icon: "film", title: "Not available",
                               message: "This title isn't in your library anymore.")
            } else {
                ProgressView().controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: movieID) {
            movie = await env.repository.movie(id: movieID)
            notFound = movie == nil
            guard let movie else { return }
            enriched = await env.metadata.details(
                for: movie.id, title: movie.title, year: movie.year, isSeries: false
            )
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
    }

    @ViewBuilder
    private func loaded(_ movie: Movie) -> some View {
        let progress = env.watchProgress.progress(for: movie.id)
        let backdrop = movie.backdropURL ?? enriched?.backdropURL ?? movie.posterURL ?? enriched?.posterURL
        let runtime = movie.durationMinutes ?? enriched?.runtime
        let genre = movie.genres.first?.displayName ?? enriched?.genres?.first
        let synopsis = movie.synopsis ?? enriched?.overview
        let cast = movie.cast.isEmpty ? (enriched?.cast ?? []) : movie.cast

        DetailScaffold(title: movie.title, backdropURL: backdrop) {
            Text(movie.title).font(.dsHero).tracking(Metrics.heroTracking).lineLimit(2)

            HStack(spacing: Metrics.space2) {
                if let rating = enriched?.rating {
                    TMDBRatingBadge(rating: rating, votes: enriched?.voteCount)
                }
                MetadataLine([
                    movie.year.map(String.init),
                    genre,
                    runtime.map { "\($0 / 60)h \($0 % 60)m" },
                    movie.quality > .unknown ? movie.quality.shortLabel : nil,
                ])
            }

            if let tagline = enriched?.tagline {
                Text(tagline)
                    .font(.dsBody.italic())
                    .foregroundStyle(Palette.textTertiary)
            }

            HStack(spacing: Metrics.space2) {
                Button {
                    Task { playback = await env.playback(forMovie: movie.id) }
                } label: {
                    Label(progress?.isResumable == true ? "Resume" : "Play", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    env.favorites.toggle(id: movie.id, kind: .movie)
                } label: {
                    Image(systemName: env.favorites.isFavorite(movie.id) ? "heart.fill" : "heart")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel(env.favorites.isFavorite(movie.id) ? "Remove from Favorites" : "Add to Favorites")
            }

            if let progress, progress.isResumable {
                ProgressView(value: progress.fraction) {
                    Text("Resume from \(timecode(progress.positionSeconds))")
                        .font(.dsCaption).foregroundStyle(Palette.textTertiary)
                }
                .tint(Palette.accent)
                .frame(maxWidth: 600)
            }

            LanguageSummary(audio: movie.audioLanguages, subtitles: movie.subtitleLanguages)

            if let synopsis {
                Text(synopsis)
                    .font(.dsBody)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: 1100, alignment: .leading)
            }

            if !movie.directors.isEmpty {
                creditRow("Director", movie.directors)
            }
            if !cast.isEmpty {
                creditRow("Cast", cast)
            }
        }
    }

    private func creditRow(_ label: String, _ names: [String]) -> some View {
        HStack(alignment: .top, spacing: Metrics.space2) {
            Text(label).font(.dsCaption).foregroundStyle(Palette.textTertiary)
                .frame(width: 140, alignment: .leading)
            Text(names.joined(separator: ", "))
                .font(.dsCaption).foregroundStyle(Palette.textSecondary)
        }
    }

    private func timecode(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
