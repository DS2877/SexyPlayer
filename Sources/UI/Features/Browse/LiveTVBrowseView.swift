import SwiftUI
import Observation

public struct LiveChannelRow: Identifiable, Sendable {
    public let id: CatalogID
    public let name: String
    public let logoURL: URL?
    public let quality: VideoQuality
    public let nowTitle: String?
    public let nowProgress: Double?
}

@MainActor
@Observable
public final class LiveTVBrowseViewModel {
    public private(set) var categories: [String] = ["All"]
    public private(set) var rows: [LiveChannelRow] = []
    public private(set) var total = 0
    public private(set) var isLoading = false
    public private(set) var canLoadMore = true

    public var selectedCategory = "All"

    private let repository: any CatalogRepository
    private let pageSize = 90
    private var page = 0

    public init(repository: any CatalogRepository) {
        self.repository = repository
    }

    public func start() async {
        categories = await repository.allChannelCategories()
        await reload()
    }

    public func reload() async {
        isLoading = true
        page = 0
        canLoadMore = true
        let category = selectedCategory
        total = await repository.channelsCount(in: category)
        guard !Task.isCancelled else { return }
        rows = []
        await loadPage(replacing: true, category: category)
        isLoading = false
    }

    public func loadMoreIfNeeded(currentItem: LiveChannelRow) async {
        guard canLoadMore, !isLoading,
              let idx = rows.firstIndex(where: { $0.id == currentItem.id }),
              idx >= rows.count - 15
        else { return }
        await loadPage(replacing: false, category: selectedCategory)
    }

    private func loadPage(replacing: Bool, category: String) async {
        isLoading = true
        defer { isLoading = false }

        let channels = await repository.channels(in: category, page: page, pageSize: pageSize)
        guard !Task.isCancelled, category == selectedCategory else { return }

        let now = Date()
        var built: [LiveChannelRow] = []
        for channel in channels {
            var nowTitle: String?
            var nowProgress: Double?
            if let epgID = channel.epgID,
               let event = await repository.nowPlaying(forEPGID: epgID, at: now) {
                nowTitle = event.title
                nowProgress = event.progress(at: now)
            }
            built.append(LiveChannelRow(
                id: channel.id, name: channel.name, logoURL: channel.logoURL,
                quality: channel.quality, nowTitle: nowTitle, nowProgress: nowProgress
            ))
        }
        guard category == selectedCategory else { return }
        if replacing { rows = built } else { rows.append(contentsOf: built) }
        page += 1
        canLoadMore = channels.count == pageSize
    }
}

struct LiveTVBrowseView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: LiveTVBrowseViewModel?
    @State private var path: [AppRoute] = []

    private let columns = Array(repeating: GridItem(.fixed(Metrics.wideCardWidth), spacing: Metrics.cardSpacing),
                                count: 4)

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let model {
                    content(model)
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
                let vm = LiveTVBrowseViewModel(repository: env.repository)
                model = vm
                await vm.start()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: LiveTVBrowseViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.space3, pinnedViews: [.sectionHeaders]) {
                Section {
                    if model.rows.isEmpty && !model.isLoading {
                        EmptyStateView(icon: "tv", title: "No channels",
                                       message: "No channels in this category.")
                            .frame(minHeight: 400)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: Metrics.shelfSpacing) {
                            ForEach(model.rows) { row in
                                ChannelCard(
                                    name: row.name,
                                    logoURL: row.logoURL,
                                    nowTitle: row.nowTitle,
                                    quality: row.quality,
                                    nowProgress: row.nowProgress,
                                    action: { path.append(.channel(row.id)) }
                                )
                                .task { await model.loadMoreIfNeeded(currentItem: row) }
                            }
                        }
                        .padding(.horizontal, Metrics.screenMargin)
                        .padding(.bottom, Metrics.space7)
                    }
                } header: {
                    header(model)
                }
            }
        }
        .onChange(of: model.selectedCategory) { _, _ in
            Task { await model.reload() }
        }
    }

    private func header(_ model: LiveTVBrowseViewModel) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Live TV").font(.dsHero)
                Text("\(model.total)").font(.dsSectionHeader).foregroundStyle(Palette.textTertiary)
            }
            if model.categories.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Metrics.space1) {
                        ForEach(model.categories, id: \.self) { category in
                            FilterChip(label: category, isSelected: model.selectedCategory == category) {
                                model.selectedCategory = category
                            }
                        }
                    }
                    .padding(.vertical, Metrics.space1)
                }
                .focusSection()
            }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, Metrics.space4)
        .padding(.bottom, Metrics.space2)
        .background(Palette.canvas.opacity(0.98))
    }
}
