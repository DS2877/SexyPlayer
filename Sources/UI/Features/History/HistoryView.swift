import SwiftUI

/// Everything the user has watched or started, newest first. Press-and-hold a
/// row to remove it; "Clear All" wipes the lot (and the Continue Watching row).
struct HistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var groups: [HistoryGroup] = []
    @State private var path: [AppRoute] = []
    @State private var confirmClear = false

    struct HistoryRow: Identifiable {
        let id: String
        let progressID: CatalogID
        let title: String
        let subtitle: String
        let art: URL?
        let fraction: Double
        let finished: Bool
        let route: AppRoute
    }

    struct HistoryGroup: Identifiable {
        let id: String
        let rows: [HistoryRow]
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if groups.isEmpty, env.loadState.isImporting, !env.watchProgress.allEntries().isEmpty {
                    LibraryLoadingPlaceholder()
                } else if groups.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "Nothing watched yet",
                        message: "Films and episodes you play show up here, so you can pick them back up on any screen."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Metrics.shelfSpacing) {
                            header
                            ForEach(groups) { group in
                                VStack(alignment: .leading, spacing: Metrics.space2) {
                                    SectionHeader(group.id).padding(.horizontal, Metrics.screenMargin)
                                    VStack(spacing: Metrics.space2) {
                                        ForEach(group.rows) { row in
                                            HistoryRowView(
                                                row: row,
                                                onOpen: { path.append(row.route) },
                                                onRemove: { remove(row) }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, Metrics.screenMargin)
                                }
                            }
                        }
                        .padding(.bottom, Metrics.space7)
                    }
                }
            }
            .appThemeBackground()
            .appRouteDestinations()
        }
        .task(id: env.watchProgress.allEntries().count) { await reload() }
        .onChange(of: path.isEmpty) { _, atRoot in if atRoot { Task { await reload() } } }
    }

    private var header: some View {
        HStack {
            Text("History").font(.dsTitle).accessibilityAddTraits(.isHeader)
            Spacer()
            Button(role: .destructive) { confirmClear = true } label: {
                Label("Clear All", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, Metrics.space4)
        .alert("Clear watch history?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) {
                env.watchProgress.clearAll()
                Task { await reload() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every resume point and the Continue Watching row. Favorites and your provider are untouched.")
        }
    }

    private func remove(_ row: HistoryRow) {
        env.watchProgress.clear(id: row.progressID)
        Task { await reload() }
    }

    private func reload() async {
        let catalog = await env.repository.snapshot()
        let moviesByID = Dictionary(catalog.movies.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        var episodeIndex: [CatalogID: (series: Series, episode: Episode)] = [:]
        for series in catalog.series {
            for season in series.seasons {
                for episode in season.episodes { episodeIndex[episode.id] = (series, episode) }
            }
        }

        var inProgress: [HistoryRow] = []
        var watched: [HistoryRow] = []

        for entry in env.watchProgress.history() {
            guard let row = makeRow(for: entry, moviesByID: moviesByID, episodeIndex: episodeIndex) else { continue }
            if entry.isFinished { watched.append(row) } else { inProgress.append(row) }
        }

        groups = [
            HistoryGroup(id: "In Progress", rows: inProgress),
            HistoryGroup(id: "Watched", rows: watched),
        ].filter { !$0.rows.isEmpty }
    }

    private func makeRow(
        for entry: WatchProgress,
        moviesByID: [CatalogID: Movie],
        episodeIndex: [CatalogID: (series: Series, episode: Episode)]
    ) -> HistoryRow? {
        switch entry.kind {
        case .movie:
            guard let movie = moviesByID[entry.itemID] else { return nil }
            return HistoryRow(
                id: entry.itemID.rawValue,
                progressID: entry.itemID,
                title: movie.title,
                subtitle: [movie.year.map(String.init), movie.genres.first?.displayName]
                    .compactMap { $0 }.joined(separator: " · "),
                art: movie.posterURL,
                fraction: entry.fraction,
                finished: entry.isFinished,
                route: .movie(movie.id)
            )
        case .series:
            guard let (series, episode) = episodeIndex[entry.itemID] else { return nil }
            return HistoryRow(
                id: entry.itemID.rawValue,
                progressID: entry.itemID,
                title: series.title,
                subtitle: "\(episode.code) · \(episode.title)",
                art: episode.stillURL ?? series.posterURL,
                fraction: entry.fraction,
                finished: entry.isFinished,
                route: .series(series.id)
            )
        case .liveChannel:
            return nil
        }
    }
}

private struct HistoryRowView: View {
    let row: HistoryView.HistoryRow
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Metrics.space3) {
                ArtworkView(url: row.art, title: row.title, aspect: 16.0 / 9.0)
                    .frame(width: 240, height: 135)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text(row.title)
                        .font(.dsCardTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    Text(row.subtitle)
                        .font(.dsCaption)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                    if row.finished {
                        Label("Watched", systemImage: "checkmark.circle.fill")
                            .font(.dsTag)
                            .foregroundStyle(Palette.accent)
                    } else {
                        ProgressView(value: row.fraction)
                            .tint(Palette.accent)
                            .frame(maxWidth: 360)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Metrics.space2)
        }
        .buttonStyle(.card)
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label("Remove from History", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(row.title), \(row.subtitle)")
        .accessibilityHint(row.finished ? "Watched" : "In progress")
    }
}
