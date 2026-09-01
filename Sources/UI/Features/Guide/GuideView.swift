import SwiftUI
import Observation

struct GuideChannelRow: Identifiable, Sendable {
    let id: CatalogID
    let name: String
    let logoURL: URL?
    let events: [EPGEvent]
}

@MainActor
@Observable
final class GuideViewModel {
    private(set) var rows: [GuideChannelRow] = []
    private(set) var isLoading = true
    /// The guide is capped so a 15k-channel provider doesn't build 15k rows.
    private(set) var truncated = false
    let now = Date()

    /// Most people never scroll past a few hundred channels in a guide.
    private static let rowCap = 250

    private let repository: any CatalogQuerying
    private var pendingLoad: Task<Void, Never>?

    init(repository: any CatalogQuerying) { self.repository = repository }

    /// Coalesced — the catalog revision bumps several times during a staged
    /// import; without this each bump kicks off another full channel scan.
    func load() async {
        pendingLoad?.cancel()
        let task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            await self.performLoad()
        }
        pendingLoad = task
        await task.value
    }

    private func performLoad() async {
        isLoading = true
        defer { isLoading = false }

        let cap = Self.rowCap
        // "For you" order, EPG-carrying channels only — the store already caps it.
        let channels = await repository.guideChannels(limit: cap)
        guard !Task.isCancelled else { return }

        let epgIDs = channels.compactMap(\.epgID)
        let window = DateInterval(start: now.addingTimeInterval(-3600),
                                  end: now.addingTimeInterval(8 * 3600))
        let epg = await repository.epgIndex(forEPGIDs: epgIDs, in: window)
        guard !Task.isCancelled else { return }

        var built: [GuideChannelRow] = []
        for channel in channels {
            guard let epgID = channel.epgID, let events = epg[epgID], !events.isEmpty else { continue }
            built.append(GuideChannelRow(id: channel.id, name: channel.name,
                                         logoURL: channel.logoURL, events: events))
        }
        rows = built
        truncated = channels.count >= cap && built.count == channels.count
    }
}

/// A vertical list of channels; each row is a horizontally-focusable strip of
/// its upcoming programmes. This is a far better fit for the Siri Remote than a
/// dense 2-D timeline grid.
struct GuideView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(SectionModels.self) private var models
    @State private var model: GuideViewModel?
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let model {
                    content(model)
                } else {
                    Color.clear
                }
            }
            .appThemeBackground()
            .appRouteDestinations()
        }
        .task(id: models.generation) {
            let shared = models.guide(env)
            model = shared
            guard models.needsLoad(.guide, revision: env.catalogRevision) else { return }
            models.markLoaded(.guide, revision: env.catalogRevision)
            await shared.load()
        }
        .onChange(of: env.catalogRevision) { _, revision in
            models.markLoaded(.guide, revision: revision)
            Task { await model?.load() }
        }
    }

    @ViewBuilder
    private func content(_ model: GuideViewModel) -> some View {
        if model.isLoading {
            SkeletonGuide()
        } else if model.rows.isEmpty, env.loadState.isImporting || !env.catalogComplete {
            SkeletonGuide()
        } else if model.rows.isEmpty {
            EmptyStateView(
                icon: "rectangle.grid.1x2",
                title: "No TV guide",
                message: "Your provider didn't include EPG data, or it hasn't matched your channels yet."
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.space3, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(model.rows) { row in
                            channelRow(row, now: model.now)
                        }
                        if model.truncated {
                            Text("Showing the first \(model.rows.count) channels with guide data. Use Live TV to browse the rest.")
                                .font(.dsCaption).foregroundStyle(Palette.textTertiary)
                                .padding(.horizontal, Metrics.screenMargin)
                                .padding(.top, Metrics.space2)
                        }
                    } header: {
                        HStack {
                            Text("TV Guide").font(.dsTitle).accessibilityAddTraits(.isHeader)
                            Spacer()
                            Text(model.now.formatted(date: .abbreviated, time: .shortened))
                                .font(.dsCaption).foregroundStyle(Palette.textTertiary)
                        }
                        .padding(.horizontal, Metrics.screenMargin)
                        .padding(.top, Metrics.space4)
                        .padding(.bottom, Metrics.space2)
                        .background(Palette.canvas.opacity(0.98))
                    }
                }
                .padding(.bottom, Metrics.space7)
            }
        }
    }

    private func channelRow(_ row: GuideChannelRow, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.name)
                .font(.dsTag)
                .foregroundStyle(Palette.textSecondary)
                .textCase(.uppercase)
                .tracking(Metrics.eyebrowTracking)
                .padding(.horizontal, Metrics.screenMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.space1) {
                    ForEach(row.events.prefix(14)) { event in
                        Button {
                            path.append(.channel(row.id))
                        } label: {
                            ProgrammeCell(event: event, now: now)
                        }
                        .buttonStyle(.card)
                        .accessibilityLabel("\(row.name), \(event.start.formatted(date: .omitted, time: .shortened)), \(event.title)\(event.isLive(at: now) ? ", on now" : "")")
                    }
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.vertical, Metrics.space1)
            }
            .focusSection()
        }
    }
}

private struct ProgrammeCell: View {
    let event: EPGEvent
    let now: Date

    private var live: Bool { event.isLive(at: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(event.start.formatted(date: .omitted, time: .shortened))
                    .font(.dsCaption).foregroundStyle(live ? Palette.accent : Palette.textTertiary)
                if live { LiveBadge() }
            }
            Text(event.title)
                .font(.dsCardTitle)
                .foregroundStyle(live ? Palette.textPrimary : Palette.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if live {
                ProgressView(value: event.progress(at: now)).tint(Palette.accent)
            }
        }
        .padding(Metrics.space2)
        .frame(width: 248, height: 118, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(live ? Palette.accent.opacity(0.55) : .clear, lineWidth: 1.5)
        )
    }
}
