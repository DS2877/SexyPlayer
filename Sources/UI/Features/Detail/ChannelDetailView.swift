import SwiftUI

/// Minimal channel screen for M2 — enough to launch playback. The rich Live TV
/// experience (EPG now/next, categories) comes in M3.
struct ChannelDetailView: View {
    let channelID: CatalogID

    @Environment(AppEnvironment.self) private var env
    @State private var channel: Channel?
    @State private var nowEvent: EPGEvent?
    @State private var playback: PlaybackItem?
    @State private var lineup: [Channel] = []

    var body: some View {
        Group {
            if let channel {
                DetailScaffold(title: channel.name, backdropURL: channel.logoURL) {
                    Text(channel.name).font(.dsHero).tracking(Metrics.heroTracking)
                    MetadataLine([
                        channel.category,
                        channel.quality > .unknown ? channel.quality.shortLabel : nil,
                        channel.countryCode,
                    ])

                    if let nowEvent {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Now playing").font(.dsCaption).foregroundStyle(Palette.textTertiary)
                            Text(nowEvent.title).font(.dsCardTitle)
                            ProgressView(value: nowEvent.progress(at: .now)).tint(Palette.accent)
                                .frame(maxWidth: 500)
                        }
                    }

                    Button {
                        Task { playback = await env.playback(forChannel: channel.id) }
                    } label: {
                        Label("Watch Live", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    LanguageSummary(audio: channel.audioLanguages, subtitles: channel.subtitleLanguages)
                }
            } else {
                ProgressView().controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: channelID) {
            channel = await env.repository.channel(id: channelID)
            if let epgID = channel?.epgID {
                nowEvent = await env.repository.nowPlaying(forEPGID: epgID, at: .now)
            }
            if lineup.isEmpty {
                lineup = await env.repository.snapshot().channels
            }
        }
        .fullScreenCover(item: $playback) { item in
            PlayerScreen(
                item: item,
                lineup: ChannelLineup(channels: lineup, currentID: item.id),
                makePlayback: { channel in await env.playback(forChannel: channel.id) },
                nowText: { channel in
                    guard let epgID = channel.epgID else { return nil }
                    return await env.repository.nowPlaying(forEPGID: epgID, at: .now)?.title
                },
                preferredAudio: env.preferences.preferences.preferredAudioLanguages,
                preferredSubtitle: env.preferences.preferences.preferredSubtitleLanguage
            ) { id, kind, position, duration in
                env.recordProgress(id: id, kind: kind, position: position, duration: duration)
            }
        }
    }
}
