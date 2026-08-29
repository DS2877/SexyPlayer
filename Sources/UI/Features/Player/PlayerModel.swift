import Foundation
import AVFoundation
import Observation

/// Owns the `AVPlayer` lifecycle for one `PlaybackItem`: start/resume, periodic
/// progress reporting, and failure detection mapped to a friendly message.
///
/// The player *UI* is Apple's `AVPlayerViewController` (see
/// `SystemPlayerView`) — this type never rebuilds transport controls.
@MainActor
@Observable
public final class PlayerModel {

    public enum State: Equatable {
        case loading
        case playing
        case failed(ProviderError)
    }

    public private(set) var state: State = .loading

    @ObservationIgnored public let player: AVPlayer
    @ObservationIgnored public let item: PlaybackItem

    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var timeObserverToken: Any?
    @ObservationIgnored private var failureObserver: NSObjectProtocol?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var hasSeekedToResume = false
    @ObservationIgnored private var loadTimeout: Task<Void, Never>?

    /// Called ~every 10s and on teardown with the current position. No-op for live.
    @ObservationIgnored
    private let onProgress: @MainActor (_ position: Double, _ duration: Double) -> Void

    /// Fired when the item plays to its end, so the host can dismiss and let
    /// "up next" take over.
    @ObservationIgnored public var onFinished: (@MainActor () -> Void)?

    public init(
        item: PlaybackItem,
        onProgress: @escaping @MainActor (Double, Double) -> Void
    ) {
        self.item = item
        self.onProgress = onProgress
        self.player = AVPlayer(url: item.url)
        self.player.automaticallyWaitsToMinimizeStalling = true

        // Refuse obviously unplayable streams up front rather than spinning.
        if case .unsupported(let reason) = StreamCompatibility.verdict(for: item.url) {
            state = .failed(.streamNotSupported(detail: reason))
            return
        }
        configure()
        startLoadTimeout()
    }

    private func startLoadTimeout() {
        loadTimeout?.cancel()
        loadTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled, let self, self.state == .loading else { return }
            self.fail(with: nil)
        }
    }

    private func configure() {
        guard let currentItem = player.currentItem else { return }

        statusObservation = currentItem.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            let status = observedItem.status
            Task { @MainActor in self?.handleStatusChange(status) }
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: currentItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fail(with: nil) }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: currentItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handlePlayedToEnd() }
        }

        if !item.isLive {
            let interval = CMTime(seconds: 10, preferredTimescale: 1)
            timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reportProgress() }
            }
        }
    }

    public func play() {
        player.play()
    }

    public func retry() {
        removeObservers()
        state = .loading
        hasSeekedToResume = false
        player.replaceCurrentItem(with: AVPlayerItem(url: item.url))
        configure()
        startLoadTimeout()
        player.play()
    }

    private func removeObservers() {
        loadTimeout?.cancel()
        loadTimeout = nil
        if let token = timeObserverToken { player.removeTimeObserver(token) }
        timeObserverToken = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        failureObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }

    /// The item finished — record it as watched so "up next" logic can fire.
    private func handlePlayedToEnd() {
        guard !item.isLive else { return }
        let duration = resolvedDuration()
        if duration > 0 { onProgress(duration, duration) }   // -> WatchProgress.isFinished
        onFinished?()
    }

    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            loadTimeout?.cancel()
            seekToResumeIfNeeded()
            state = .playing
            player.play()
        case .failed:
            fail(with: player.currentItem?.error)
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func seekToResumeIfNeeded() {
        guard !hasSeekedToResume, !item.isLive, let resumeAt = item.resumeAt, resumeAt > 1 else { return }
        hasSeekedToResume = true
        player.seek(to: CMTime(seconds: resumeAt, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func fail(with error: Error?) {
        let providerError: ProviderError = error.map(ProviderError.from) ?? .streamUnavailable
        state = .failed(providerError)
        AppLog.player.error("Playback failed for \(self.item.id.rawValue, privacy: .public): \(String(describing: providerError))")
    }

    private func reportProgress() {
        guard !item.isLive else { return }
        let position = player.currentTime().seconds
        let duration = resolvedDuration()
        guard position.isFinite, position > 0, duration > 0 else { return }
        onProgress(position, duration)
    }

    private func resolvedDuration() -> Double {
        if let known = item.durationSeconds, known > 0 { return known }
        let d = player.currentItem?.duration.seconds ?? 0
        return d.isFinite ? d : 0
    }

    /// Call from the view's `onDisappear`.
    public func teardown() {
        reportProgress()
        player.pause()
        removeObservers()
    }
}
