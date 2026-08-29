import SwiftUI
import AVKit

/// Full-screen playback. Hosts Apple's native `AVPlayerViewController` and lays
/// a friendly error state over it if the stream fails.
struct PlayerScreen: View {
    let item: PlaybackItem
    let onProgress: @MainActor (CatalogID, ContentKind, Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: PlayerModel?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let model {
                SystemPlayerView(player: model.player)
                    .ignoresSafeArea()

                switch model.state {
                case .loading:
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                case .failed(let error):
                    ErrorStateView(
                        error: error,
                        onRetry: { model.retry() },
                        onEditProvider: { dismiss() }
                    )
                    .background(.black.opacity(0.85))
                    .ignoresSafeArea()
                case .playing:
                    EmptyView()
                }
            }
        }
        .onAppear {
            if model == nil {
                model = PlayerModel(item: item) { position, duration in
                    onProgress(item.id, item.kind, position, duration)
                }
                model?.play()
            }
        }
        .onDisappear { model?.teardown() }
    }
}

/// Thin wrapper around `AVPlayerViewController` — no custom transport controls.
struct SystemPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspect
        // Show the native Info panel with title/description when the user swipes down.
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}
