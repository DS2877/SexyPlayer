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
                    SystemPlayerView(player: model.player).ignoresSafeArea()
                    if model.state == .loading {
                        ProgressView().controlSize(.large).tint(.white)
                    }
                }
            }
        }
        .onAppear {
            if model == nil {
                let m = PlayerModel(item: item) { position, duration in
                    onProgress(item.id, item.kind, position, duration)
                }
                m.onFinished = { dismiss() }
                model = m
                m.play()
            }
        }
        .onDisappear { model?.teardown() }
    }

    private func canRetry(_ error: ProviderError) -> Bool {
        if case .streamNotSupported = error { return false }
        return true
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
