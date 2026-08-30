import SwiftUI

/// The ordered set of channels the player can zap between, plus where we are in
/// it. Wrapping keeps prev/next infinite.
struct ChannelLineup {
    let channels: [Channel]
    let currentID: CatalogID

    var currentIndex: Int? { channels.firstIndex { $0.id == currentID } }

    func channel(offset: Int) -> Channel? {
        guard !channels.isEmpty, let index = currentIndex else { return nil }
        let count = channels.count
        return channels[((index + offset) % count + count) % count]
    }

    func moved(to id: CatalogID) -> ChannelLineup {
        ChannelLineup(channels: channels, currentID: id)
    }
}

/// Brief overlay shown at the bottom of the picture when a channel changes,
/// like a TV's channel banner. Auto-dismissed by the caller.
struct ChannelBanner: View {
    struct Info: Identifiable, Equatable {
        let id = UUID()
        let channelName: String
        let category: String
        let nowPlaying: String?
    }

    let info: Info

    var body: some View {
        HStack(spacing: Metrics.space2) {
            Image(systemName: "tv")
                .font(.system(size: 30))
                .foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(info.channelName)
                    .font(.dsCardTitle)
                    .foregroundStyle(.white)
                Text(info.nowPlaying.map { "Now: \($0)" } ?? info.category)
                    .font(.dsCaption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, Metrics.space3)
        .padding(.vertical, Metrics.space2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .strokeBorder(Palette.hairline)
        )
    }
}

/// Full-screen channel list for zapping — the video keeps playing behind it.
/// Menu button closes it.
struct ChannelZapPanel: View {
    let lineup: ChannelLineup
    var nowText: (@MainActor (Channel) async -> String?)?
    let onPick: (Channel) -> Void
    let onClose: () -> Void

    @FocusState private var focused: CatalogID?
    @State private var nowByID: [CatalogID: String] = [:]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.canvas.opacity(0.96).ignoresSafeArea()

            VStack(alignment: .leading, spacing: Metrics.space3) {
                Text("Channels")
                    .font(.dsTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, Metrics.screenMargin)
                    .padding(.top, Metrics.space5)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Metrics.space1) {
                            ForEach(lineup.channels) { channel in
                                row(channel)
                                    .id(channel.id)
                                    .focused($focused, equals: channel.id)
                            }
                        }
                        .padding(.horizontal, Metrics.screenMargin)
                        .padding(.bottom, Metrics.space6)
                    }
                    .onAppear {
                        focused = lineup.currentID
                        proxy.scrollTo(lineup.currentID, anchor: .center)
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
        .onExitCommand { onClose() }
        .task {
            guard let nowText else { return }
            for channel in lineup.channels.prefix(60) {
                if let text = await nowText(channel) { nowByID[channel.id] = text }
            }
        }
    }

    private func row(_ channel: Channel) -> some View {
        Button { onPick(channel) } label: {
            HStack(spacing: Metrics.space2) {
                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(channel.id == lineup.currentID ? Palette.accent : .clear)
                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.dsCardTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    if let now = nowByID[channel.id] {
                        Text(now)
                            .font(.dsCaption)
                            .foregroundStyle(Palette.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if channel.quality > .unknown {
                    Text(channel.quality.shortLabel)
                        .font(.dsTag)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .buttonStyle(RowButtonStyle())
    }
}
