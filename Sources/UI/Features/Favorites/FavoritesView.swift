import SwiftUI

struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var sections: [FavSection] = []
    @State private var path: [AppRoute] = []

    private let columns = Array(repeating: GridItem(.fixed(Metrics.posterWidth), spacing: Metrics.cardSpacing),
                                count: 5)

    struct FavItem: Identifiable {
        let id: CatalogID
        let title: String
        let subtitle: String
        let art: URL?
        let route: AppRoute
    }
    struct FavSection: Identifiable {
        let id: String
        let items: [FavItem]
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if sections.isEmpty {
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

                            ForEach(sections) { section in
                                VStack(alignment: .leading, spacing: Metrics.space2) {
                                    SectionHeader(section.id).padding(.horizontal, Metrics.screenMargin)
                                    LazyVGrid(columns: columns, alignment: .leading, spacing: Metrics.shelfSpacing) {
                                        ForEach(section.items) { item in
                                            PosterCard(title: item.title, subtitle: item.subtitle,
                                                       artworkURL: item.art,
                                                       action: { path.append(item.route) })
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
        .task(id: env.favorites.all().count) { await reload() }
        .onChange(of: path.isEmpty) { _, atRoot in if atRoot { Task { await reload() } } }
    }

    private func reload() async {
        let catalog = await env.repository.snapshot()
        let ids = Set(env.favorites.all().map(\.itemID))

        let movies = catalog.movies.filter { ids.contains($0.id) }.map { m in
            FavItem(id: m.id, title: m.title,
                    subtitle: [m.year.map(String.init), m.genres.first?.displayName].compactMap { $0 }.joined(separator: " · "),
                    art: m.posterURL, route: .movie(m.id))
        }
        let series = catalog.series.filter { ids.contains($0.id) }.map { s in
            FavItem(id: s.id, title: s.title,
                    subtitle: "\(s.seasons.count) season\(s.seasons.count == 1 ? "" : "s")",
                    art: s.posterURL, route: .series(s.id))
        }
        let channels = catalog.channels.filter { ids.contains($0.id) }.map { c in
            FavItem(id: c.id, title: c.name, subtitle: c.category, art: c.logoURL, route: .channel(c.id))
        }

        sections = [
            FavSection(id: "Movies", items: movies),
            FavSection(id: "Series", items: series),
            FavSection(id: "Channels", items: channels),
        ].filter { !$0.items.isEmpty }
    }
}
