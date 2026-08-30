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
            VLCPlayerScreen(item: item, onProgress: onProgress)
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

                    if model.state == .loading {
                        ProgressView().controlSize(.large).tint(.white)
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
                    nowText: nowText,
                    onPick: { channel in
                        showChannelPanel = false
                        switchTo(channel)
                    },
                    onClose: { showChannelPanel = false }
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: banner?.id)
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
