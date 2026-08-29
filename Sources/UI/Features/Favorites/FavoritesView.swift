import SwiftUI

struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var movies: [Movie] = []
    @State private var series: [Series] = []
    @State private var channels: [Channel] = []
    @State private var path: [AppRoute] = []

    private let columns = Array(repeating: GridItem(.fixed(Metrics.posterWidth), spacing: Metrics.cardSpacing),
                                count: 5)

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if movies.isEmpty && series.isEmpty && channels.isEmpty {
                    EmptyStateView(
                        icon: "heart",
                        title: "No favorites yet",
                        message: "Press the heart on any movie, series or channel and it'll show up here."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Metrics.shelfSpacing) {
                            Text("Favorites").font(.dsHero)
                                .padding(.horizontal, Metrics.screenMargin)
                                .padding(.top, Metrics.space4)

                            grid("Movies", movies.map { ($0.id, $0.title, subtitle(for: $0), $0.posterURL, AppRoute.movie($0.id)) })
                            grid("Series", series.map { ($0.id, $0.title, "\($0.seasons.count) seasons", $0.posterURL, AppRoute.series($0.id)) })
                            grid("Channels", channels.map { ($0.id, $0.name, $0.category, $0.logoURL, AppRoute.channel($0.id)) })
                        }
                        .padding(.bottom, Metrics.space7)
                    }
                }
            }
            .appThemeBackground()
            .appRouteDestinations()
        }
        .task(id: env.favorites.all().count) { await reload() }
        .onChange(of: path.isEmpty) { _, atRoot in if atRoot { Task { await reload() } } }
    }

    @ViewBuilder
    private func grid(_ title: String, _ items: [(CatalogID, String, String, URL?, AppRoute)]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.space2) {
                SectionHeader(title).padding(.horizontal, Metrics.screenMargin)
                LazyVGrid(columns: columns, alignment: .leading, spacing: Metrics.shelfSpacing) {
                    ForEach(items, id: \.0) { item in
                        PosterCard(title: item.1, subtitle: item.2, artworkURL: item.3,
                                   action: { path.append(item.4) })
                    }
                }
                .padding(.horizontal, Metrics.screenMargin)
            }
        }
    }

    private func subtitle(for m: Movie) -> String {
        [m.year.map(String.init), m.genres.first?.displayName].compactMap { $0 }.joined(separator: " · ")
    }

    private func reload() async {
        let catalog = await env.repository.snapshot()
        let favs = env.favorites.all()
        let ids = Set(favs.map(\.itemID))
        movies = catalog.movies.filter { ids.contains($0.id) }
        series = catalog.series.filter { ids.contains($0.id) }
        channels = catalog.channels.filter { ids.contains($0.id) }
    }
}
