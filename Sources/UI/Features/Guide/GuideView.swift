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
    let now = Date()

    private let repository: any CatalogRepository

    init(repository: any CatalogRepository) { self.repository = repository }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let catalog = await repository.snapshot()
        let window = DateInterval(start: now.addingTimeInterval(-3600),
                                  end: now.addingTimeInterval(8 * 3600))
        rows = catalog.channels.compactMap { channel -> GuideChannelRow? in
            guard let epgID = channel.epgID else { return nil }
            let events = catalog.events(forEPGID: epgID, in: window)
            guard !events.isEmpty else { return nil }
            return GuideChannelRow(id: channel.id, name: channel.name,
                                   logoURL: channel.logoURL, events: events)
        }
    }
}

/// A vertical list of channels; each row is a horizontally-focusable strip of
/// its upcoming programmes. This is a far better fit for the Siri Remote than a
/// dense 2-D timeline grid.
struct GuideView: View {
    @Environment(AppEnvironment.self) private var env
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
        .task {
            if model == nil {
                let vm = GuideViewModel(repository: env.repository)
                model = vm
                await vm.load()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: GuideViewModel) -> some View {
        if model.isLoading {
            ProgressView().controlSize(.large).tint(Palette.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.rows.isEmpty {
            EmptyStateView(
                icon: "rectangle.grid.1x2",
                title: "No TV guide",
                message: "Your provider didn't include EPG data, or it hasn't matched your channels yet."
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.space4, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(model.rows) { row in
                            channelRow(row, now: model.now)
                        }
                    } header: {
                        HStack {
                            Text("TV Guide").font(.dsHero)
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
        VStack(alignment: .leading, spacing: Metrics.space1) {
            Text(row.name)
                .font(.dsCardTitle)
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Metrics.screenMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.space1) {
                    ForEach(row.events.prefix(12)) { event in
                        Button {
                            path.append(.channel(row.id))
                        } label: {
                            ProgrammeCell(event: event, now: now)
                        }
                        .buttonStyle(.card)
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
                .font(.dsBody)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if live {
                ProgressView(value: event.progress(at: now)).tint(Palette.accent)
            }
        }
        .padding(Metrics.space2)
        .frame(width: 300, height: 150, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardCornerRadius)
                .strokeBorder(live ? Palette.accent.opacity(0.6) : Palette.hairline)
        )
    }
}
