import SwiftUI

struct VODBrowseView: View {
    let kind: BrowseKind

    @Environment(AppEnvironment.self) private var env
    @State private var model: VODBrowseViewModel?
    @State private var showFilters = false
    @State private var path: [AppRoute] = []

    private let columns = Array(repeating: GridItem(.fixed(Metrics.posterWidth), spacing: Metrics.cardSpacing),
                                count: 5)

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let model {
                    grid(model)
                } else {
                    ProgressView().controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .appThemeBackground()
            .appRouteDestinations()
        }
        .task {
            if model == nil {
                let vm = VODBrowseViewModel(kind: kind, repository: env.repository, watchProgress: env.watchProgress)
                vm.filter.sort = env.preferences.preferences.defaultSort
                model = vm
                await vm.start()
                prefetchPosters(vm)
            }
        }
        .onChange(of: path.isEmpty) { _, atRoot in
            if atRoot { Task { await model?.start() } }
        }
        .onChange(of: env.catalogRevision) { _, _ in
            Task {
                await model?.start()
                if let model { prefetchPosters(model) }
            }
        }
    }

    private func prefetchPosters(_ model: VODBrowseViewModel) {
        ImageCache.shared.prefetch(model.cards.prefix(15).compactMap(\.posterURL))
    }

    @ViewBuilder
    private func grid(_ model: VODBrowseViewModel) -> some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.space3, pinnedViews: [.sectionHeaders]) {
                Section {
                    if model.cards.isEmpty && !model.isLoading && (env.loadState.isImporting || !env.catalogComplete) {
                        LibraryLoadingPlaceholder().frame(minHeight: 400)
                    } else if model.cards.isEmpty && !model.isLoading {
                        EmptyStateView(
                            icon: "line.3.horizontal.decrease.circle",
                            title: model.filter.isNarrowed ? "No matches" : "Nothing here yet",
                            message: model.filter.isNarrowed
                                ? "Nothing in your library matches these filters."
                                : "Your provider didn't return any \(kind.title.lowercased()).",
                            actionTitle: model.filter.isNarrowed ? "Clear filters" : nil,
                            action: model.filter.isNarrowed ? { model.clearFilters() } : nil
                        )
                        .frame(minHeight: 400)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: Metrics.gridSpacing) {
                            ForEach(model.cards) { card in
                                PosterCard(
                                    title: card.title,
                                    subtitle: card.subtitle,
                                    artworkURL: card.posterURL,
                                    ref: card.artworkRef,
                                    progress: card.progress,
                                    action: { path.append(card.route) }
                                )
                                .task { await model.loadMoreIfNeeded(currentItem: card) }
                            }
                        }
                        .padding(.horizontal, Metrics.screenMargin)
                        .padding(.bottom, Metrics.space7)
                    }
                } header: {
                    header(model, proxy: proxy)
                }
            }
        }
        .scrollClipDisabled()
        .onChange(of: model.filter) { _, _ in
            model.scheduleReload()
        }
        }
    }

    @ViewBuilder
    private func letterRail(_ model: VODBrowseViewModel, proxy: ScrollViewProxy) -> some View {
        if model.anchors.count > 2 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.space1) {
                    ForEach(model.anchors) { anchor in
                        FilterChip(label: anchor.letter, isSelected: false) {
                            Task {
                                if let id = await model.jump(to: anchor) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo(id, anchor: UnitPoint(x: 0, y: 0.12))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, Metrics.space1)
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
            .focusSection()
            .accessibilityLabel("Jump to letter")
        }
    }

    private func header(_ model: VODBrowseViewModel, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.space2) {
                Text(kind.title).font(.dsTitle).accessibilityAddTraits(.isHeader)
                if !(model.isLoading && model.cards.isEmpty) {
                    Text("\(model.total)")
                        .font(.dsCardTitle).foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                Button {
                    showFilters = true
                } label: {
                    Label(model.filter.isNarrowed ? "Filters · \(model.filter.activeChips.count)" : "Filters",
                          systemImage: "line.3.horizontal.decrease")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if !model.availableGenres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Metrics.space1) {
                        ForEach(model.availableGenres, id: \.self) { genre in
                            FilterChip(
                                label: genre.displayName,
                                isSelected: model.filter.genres.contains(genre)
                            ) {
                                toggleGenre(genre, model)
                            }
                        }
                    }
                    .padding(.vertical, Metrics.space1)
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
                .focusSection()
            }

            letterRail(model, proxy: proxy)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, Metrics.space5)
        .padding(.bottom, Metrics.space3)
        .background(Palette.canvas.opacity(0.98))
        // One region: pressing ↑ from the grid lands on the last-used control
        // here (a chip or Filters), ↓ returns to the grid.
        .focusSection()
        .sheet(isPresented: $showFilters) {
            FilterSheet(
                filter: Binding(get: { model.filter }, set: { model.filter = $0 }),
                genres: model.availableGenres,
                audio: model.availableAudio,
                subtitles: model.availableSubtitles
            )
        }
    }

    private func toggleGenre(_ genre: Genre, _ model: VODBrowseViewModel) {
        if let idx = model.filter.genres.firstIndex(of: genre) {
            model.filter.genres.remove(at: idx)
        } else {
            model.filter.genres.append(genre)
        }
    }
}
