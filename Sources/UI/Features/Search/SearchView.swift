import SwiftUI

struct SearchView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: SearchViewModel?
    @State private var path: [AppRoute] = []

    private let examples = [
        "Something scary with Swedish subtitles",
        "English series released after 2020",
        "A comedy under 90 minutes",
        "Something like Game of Thrones",
        "4K action movies",
    ]

    private let columns = Array(repeating: GridItem(.fixed(Metrics.posterWidth), spacing: Metrics.cardSpacing),
                                count: 5)

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let model {
                    contentBody(model)
                } else {
                    Color.clear
                }
            }
            .appThemeBackground()
            .appRouteDestinations()
        }
        .task {
            if model == nil {
                model = SearchViewModel(repository: env.repository,
                                        engine: env.searchEngine,
                                        ai: env.aiService)
            }
        }
    }

    @ViewBuilder
    private func contentBody(_ model: SearchViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.space4) {
                header(model)

                if model.isSearching {
                    ProgressView().controlSize(.large).tint(Palette.accent)
                        .frame(maxWidth: .infinity).padding(.top, Metrics.space6)
                } else if !model.hasSearched {
                    exampleQueries(model)
                } else if model.results.isEmpty, env.loadState.isImporting {
                    LibraryLoadingPlaceholder().frame(minHeight: 360)
                } else if model.results.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Nothing matched",
                        message: "\u{201C}\(model.interpretedFrom)\u{201D} didn't turn up anything in your library. Try removing a filter or rephrasing.",
                        actionTitle: "Clear",
                        action: { model.clear() }
                    )
                    .frame(minHeight: 360)
                } else {
                    results(model)
                }
            }
            .padding(Metrics.screenMargin)
        }
    }

    private func header(_ model: SearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space3) {
            Text("Search").font(.dsTitle).accessibilityAddTraits(.isHeader)

            HStack(spacing: Metrics.space2) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Palette.textTertiary)
                TextField("What do you want to watch?", text: Binding(
                    get: { model.query },
                    set: { model.query = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.dsCardTitle)
                .onSubmit { Task { await model.search(vocabulary: env.vocabulary) } }
            }
            .padding(.horizontal, Metrics.space3)
            .padding(.vertical, Metrics.space2 + 4)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.06))
            )
            .frame(maxWidth: 1100)

            if !model.chips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interpreted as").font(.dsCaption).foregroundStyle(Palette.textTertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Metrics.space1) {
                            ForEach(model.chips) { chip in
                                FilterChip(label: chip.label, isSelected: true, showsRemoveIcon: true) {
                                    model.removeChip(chip)
                                }
                            }
                        }
                    }
                    .focusSection()
                    if model.hasSearched {
                        Text("\(model.results.count) result\(model.results.count == 1 ? "" : "s")")
                            .font(.dsCaption).foregroundStyle(Palette.textSecondary)
                    }
                }
            }
        }
    }

    private func exampleQueries(_ model: SearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            Text("Try asking for…").font(.dsSectionHeader)
            ForEach(examples, id: \.self) { example in
                Button {
                    model.query = example
                    Task { await model.search(vocabulary: env.vocabulary) }
                } label: {
                    HStack(spacing: Metrics.space2) {
                        Image(systemName: "sparkle").foregroundStyle(Palette.accent)
                        Text(example).font(.dsBody).foregroundStyle(Palette.textPrimary)
                        Spacer()
                    }
                }
                .buttonStyle(RowButtonStyle())
                .accessibilityLabel("Search: \(example)")
            }
        }
        .frame(maxWidth: 900, alignment: .leading)
    }

    private func results(_ model: SearchViewModel) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Metrics.gridSpacing) {
            ForEach(model.results) { result in
                switch result.item {
                case .movie(let m):
                    PosterCard(title: m.title,
                               subtitle: [m.year.map(String.init), m.genres.first?.displayName].compactMap { $0 }.joined(separator: " · "),
                               artworkURL: m.posterURL,
                               action: { path.append(.movie(m.id)) })
                case .series(let s):
                    PosterCard(title: s.title,
                               subtitle: "\(s.seasons.count) season\(s.seasons.count == 1 ? "" : "s")",
                               artworkURL: s.posterURL,
                               action: { path.append(.series(s.id)) })
                case .channel(let c):
                    PosterCard(title: c.name, subtitle: c.category, artworkURL: c.logoURL,
                               action: { path.append(.channel(c.id)) })
                }
            }
        }
    }
}
