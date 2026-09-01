import SwiftUI
import AVKit
import UIKit

/// Full-screen playback. Hosts Apple's native `AVPlayerViewController` and lays
/// a friendly error state over it if the stream fails. For live channels it also
/// offers channel zapping — a transport-bar "Channels" menu plus prev/next.
struct PlayerScreen: View {
    let item: PlaybackItem
    /// Sibling channels for zapping (live only). `nil` for movies / episodes.
    var lineup: ChannelLineup? = nil
    /// Resolve a `PlaybackItem` for a channel we're zapping to.
    var makePlayback: (@MainActor (Channel) async -> PlaybackItem?)? = nil
    /// "Now playing" text for the channel banner, if EPG is available.
    var nowText: (@MainActor (Channel) async -> String?)? = nil
    /// Batched "on now" for the zap panel's visible channels.
    var nowTexts: (@MainActor ([Channel]) async -> [CatalogID: String])? = nil
    /// The viewer's language preferences, applied to the stream's tracks.
    var preferredAudio: [Language] = []
    var preferredSubtitle: Language? = nil
    let onProgress: @MainActor (CatalogID, ContentKind, Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: PlayerModel?
    @State private var currentLineup: ChannelLineup?
    @State private var showChannelPanel = false
    @State private var banner: ChannelBanner.Info?

    private var canZap: Bool {
        (currentLineup?.channels.count ?? 0) > 1 && makePlayback != nil
    }

    @ViewBuilder
    var body: some View {
        switch PlaybackEngine.choose(for: item.url) {
        case .vlc:
            VLCPlayerScreen(item: item,
                            preferredAudio: preferredAudio,
                            preferredSubtitle: preferredSubtitle,
                            onProgress: onProgress)
        case .system:
            systemBody
        }
    }

    private var systemBody: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let model {
                if case .failed(let error) = model.state {
                    VStack(spacing: Metrics.space3) {
                        ErrorStateView(
                            error: error,
                            onRetry: canRetry(error) ? { model.retry() } : nil,
                            onEditProvider: nil
                        )
                        Button("Close", action: { dismiss() })
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.95))
                    .ignoresSafeArea()
                } else {
                    SystemPlayerView(
                        player: model.player,
                        channelActions: canZap ? SystemPlayerView.ChannelActions(
                            openList: { showChannelPanel = true },
                            next: { zap(offset: 1) },
                            previous: { zap(offset: -1) }
                        ) : nil
                    )
                    .ignoresSafeArea()

                    if model.state == .loading || model.isStalling {
                        PlaybackLoadingOverlay(
                            title: model.activeItem.title,
                            subtitle: model.activeItem.subtitle,
                            isStalling: model.isStalling
                        )
                        .transition(.opacity)
                    }

                    if let info = banner {
                        ChannelBanner(info: info)
                            .padding(Metrics.screenMargin)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showChannelPanel) {
            if let lineup = currentLineup {
                ChannelZapPanel(
                    lineup: lineup,
                    nowTexts: nowTexts,
                    onPick: { channel in
                        showChannelPanel = false
                        switchTo(channel)
                    },
                    onClose: { showChannelPanel = false }
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: banner?.id)
        .animation(.easeInOut(duration: 0.28), value: model?.state == .loading)
        .animation(.easeInOut(duration: 0.28), value: model?.isStalling)
        .onAppear {
            currentLineup = lineup
            if model == nil {
                let m = PlayerModel(item: item,
                                    preferredAudio: preferredAudio,
                                    preferredSubtitle: preferredSubtitle) { played, position, duration in
                    onProgress(played.id, played.kind, position, duration)
                }
                m.onFinished = { dismiss() }
                model = m
                m.play()
            }
        }
        .onDisappear { model?.teardown() }
        .task(id: banner?.id) {
            guard banner != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            banner = nil
        }
    }

    private func zap(offset: Int) {
        guard let next = currentLineup?.channel(offset: offset) else { return }
        switchTo(next)
    }

    private func switchTo(_ channel: Channel) {
        guard let model, let makePlayback else { return }
        Task { @MainActor in
            guard let next = await makePlayback(channel) else { return }
            model.switchTo(next)
            currentLineup = currentLineup?.moved(to: channel.id)
            var now: String?
            if let nowText { now = await nowText(channel) }
            banner = ChannelBanner.Info(channelName: channel.name,
                                        category: channel.category,
                                        nowPlaying: now)
        }
    }

    private func canRetry(_ error: ProviderError) -> Bool {
        if case .streamNotSupported = error { return false }
        return true
    }
}

/// What you look at while a stream opens. A bare spinner on black reads as
/// "something is broken"; naming the thing you just chose reads as "it's
/// coming". Doubles as the buffering state mid-playback.
private struct PlaybackLoadingOverlay: View {
    let title: String
    let subtitle: String?
    let isStalling: Bool

    var body: some View {
        VStack(spacing: Metrics.space3) {
            ProgressView().controlSize(.large).tint(.white)

            VStack(spacing: 6) {
                Text(title)
                    .font(.dsCardTitle)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.dsCaption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Text(isStalling ? "Buffering…" : "Starting…")
                    .font(.dsTag)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 2)
            }
            .frame(maxWidth: 900)
            .multilineTextAlignment(.center)
        }
        .padding(Metrics.space5)
        // A scrim only while the picture is still black; once frames are
        // arriving (a stall) it stays light so you can see them resume.
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(isStalling ? 0.45 : 0))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isStalling ? "Buffering \(title)" : "Loading \(title)")
    }
}

/// Thin wrapper around `AVPlayerViewController`. Adds custom transport-bar menu
/// items for live channel zapping; callbacks are refreshed through the
/// coordinator so the menu is built only once.
struct SystemPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    var channelActions: ChannelActions? = nil

    struct ChannelActions {
        var openList: () -> Void
        var next: () -> Void
        var previous: () -> Void
    }

    func makeCoordinator() -> Coordinator { Coordinator(actions: channelActions) }

    final class Coordinator {
        var actions: ChannelActions?
        init(actions: ChannelActions?) { self.actions = actions }
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspect
        controller.showsPlaybackControls = true

        if channelActions != nil {
            let coordinator = context.coordinator
            controller.transportBarCustomMenuItems = [
                UIAction(title: "Previous Channel",
                         image: UIImage(systemName: "backward.end.fill")) { _ in coordinator.actions?.previous() },
                UIAction(title: "Channels",
                         image: UIImage(systemName: "list.bullet")) { _ in coordinator.actions?.openList() },
                UIAction(title: "Next Channel",
                         image: UIImage(systemName: "forward.end.fill")) { _ in coordinator.actions?.next() },
            ]
        }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.actions = channelActions
        if controller.player !== player {
            controller.player = player
        }
    }
}
