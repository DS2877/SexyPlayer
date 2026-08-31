import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: HomeViewModel?
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch environment.loadState {
                case .idle, .loading:
                    loadingView
                case .failed(let error):
                    ErrorStateView(error: error, onRetry: {
                        Task { await environment.bootstrap(forceReload: true) }
                    })
                case .ready:
                    if let model, !(model.content.rows.isEmpty && !environment.catalogComplete) {
                        readyView(model: model)
                    } else {
                        loadingView
                    }
                }
            }
            .appThemeBackground()
            .appRouteDestinations()
        }
        .task(id: environment.loadState) {
            guard case .ready = environment.loadState else { return }
            let model = model ?? HomeViewModel(
                repository: environment.repository,
                watchProgress: environment.watchProgress,
                preferences: environment.preferences,
                metadata: environment.metadata
            )
            self.model = model
            await model.rebuild()
            prefetchArtwork(model)
        }
        .onChange(of: path.isEmpty) { _, backAtRoot in
            // Returning to Home refreshes Continue Watching after playback.
            if backAtRoot { Task { await model?.rebuild() } }
        }
        .onChange(of: environment.isRefreshing) { _, refreshing in
            // A background library refresh just finished — rebuild shelves.
            if !refreshing { Task { await model?.rebuild() } }
        }
        .onChange(of: environment.preferences.preferences) { _, _ in
            Task { await model?.rebuild() }
        }
        .onChange(of: environment.catalogRevision) { _, _ in
            Task {
                await model?.rebuild()
                if let model { prefetchArtwork(model) }
            }
        }
        .onChange(of: environment.metadataRevision) { _, _ in
            Task { await model?.rebuild() }
        }
    }

    /// Warm the image cache for the hero and the first few rows so Home looks
    /// populated the instant it appears rather than filling in poster by poster.
    private func prefetchArtwork(_ model: HomeViewModel) {
        var urls: [URL] = model.content.heroes.compactMap(\.artworkURL)
        for row in model.content.rows.prefix(3) {
            urls += row.cards.prefix(8).compactMap(\.artworkURL)
        }
        ImageCache.shared.prefetch(urls)
    }

    private var loadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.shelfSpacing) {
                SkeletonBox(cornerRadius: 0)
                    .frame(height: 620)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: Metrics.space2) {
                            SkeletonBox(cornerRadius: 8).frame(width: 460, height: 56)
                            SkeletonBox(cornerRadius: 6).frame(width: 620, height: 24)
                            SkeletonBox(cornerRadius: 12).frame(width: 190, height: 54)
                                .padding(.top, Metrics.space2)
                        }
                        .padding(.horizontal, Metrics.screenMargin)
                        .padding(.bottom, Metrics.space5)
                    }
                SkeletonShelf()
                SkeletonShelf()
                SkeletonShelf()
            }
        }
        .scrollDisabled(true)
    }

    @ViewBuilder
    private func readyView(model: HomeViewModel) -> some View {
        if model.content.rows.isEmpty {
            EmptyStateView(
                icon: "tv",
                title: "Nothing to show yet",
                message: "Your library loaded but came back empty. Check your provider in Settings."
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !model.content.heroes.isEmpty {
                        HeroBanner(heroes: model.content.heroes) { navigate($0) }
                            .padding(.bottom, Metrics.space5)
                    }

                    LazyVStack(alignment: .leading, spacing: Metrics.shelfSpacing) {
                        if !model.content.tonight.isEmpty {
                            TonightRail(items: model.content.tonight)
                        }

                        ForEach(model.content.rows) { row in
                            Shelf(title: row.title, subtitle: row.subtitle, items: row.cards) { card in
                                cardView(card)
                            }
                        }
                    }
                }
                .padding(.bottom, Metrics.space7)
            }
        }
    }

    @ViewBuilder
    private func cardView(_ card: HomeCard) -> some View {
        switch card.kind {
        case .channel:
            ChannelCard(
                name: card.title,
                logoURL: card.artworkURL,
                nowTitle: card.subtitle,
                quality: .unknown,
                action: { navigate(card) }
            )
        case .movie, .series:
            PosterCard(
                title: card.title,
                subtitle: card.subtitle,
                artworkURL: card.artworkURL,
                ref: card.artworkRef,
                badge: card.badge,
                progress: card.progress,
                action: { navigate(card) }
            )
        }
    }

    private func navigate(_ card: HomeCard) {
        switch card.kind {
        case .movie:   path.append(.movie(card.id))
        case .series:  path.append(.series(card.id))
        case .channel: path.append(.channel(card.id))
        }
    }
}

/// The "Tonight" discovery rail — EPG-driven.
struct TonightRail: View {
    let items: [TonightItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            SectionHeader("Tonight", subtitle: "What's coming up across your channels")
                .padding(.horizontal, Metrics.screenMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Metrics.space2) {
                    ForEach(items) { item in
                        NavigationLink(value: AppRoute.channel(item.channelID)) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: Metrics.space1) {
                                    Text(item.time)
                                        .font(.dsTag)
                                        .foregroundStyle(Palette.accent)
                                    if item.isLiveNow { LiveBadge() }
                                    Spacer(minLength: 0)
                                }
                                Text(item.programTitle)
                                    .font(.dsCardTitle)
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                                Text(item.channelName)
                                    .font(.dsCaption)
                                    .foregroundStyle(Palette.textTertiary)
                                    .lineLimit(1)
                            }
                            .padding(Metrics.space2)
                            .frame(width: 256, height: 150, alignment: .leading)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.vertical, Metrics.space3)
            }
        }
        .focusSection()
    }
}
