import Foundation
import Observation
import UIKit
import VLCKitSPM

/// Playback via libVLC for the containers `AVPlayer` can't open (MKV, AVI, raw
/// MPEG-TS, rtmp/rtsp). Mirrors `PlayerModel`'s surface so `PlayerScreen` can
/// route to either. Deliberately small for v1 — video, play/pause, seek,
/// resume, progress. Track selection comes in a follow-up.
@MainActor
@Observable
public final class VLCPlayerModel {

    public enum State: Equatable {
        case loading
        case playing
        case paused
        case failed(ProviderError)
    }

    public private(set) var state: State = .loading
    public private(set) var position: Double = 0      // seconds
    public private(set) var duration: Double = 0      // seconds, 0 when unknown / live

    @ObservationIgnored public let item: PlaybackItem
    @ObservationIgnored private let player = VLCMediaPlayer()
    @ObservationIgnored private lazy var coordinator = Coordinator(owner: self)
    @ObservationIgnored private var hasSeekedToResume = false
    @ObservationIgnored private var started = false
    @ObservationIgnored private var loadTimeout: Task<Void, Never>?

    @ObservationIgnored
    private let onProgress: @MainActor (_ item: PlaybackItem, _ position: Double, _ duration: Double) -> Void
    @ObservationIgnored public var onFinished: (@MainActor () -> Void)?

    public init(
        item: PlaybackItem,
        onProgress: @escaping @MainActor (PlaybackItem, Double, Double) -> Void
    ) {
        self.item = item
        self.onProgress = onProgress
    }

    /// Attach VLC's output to a view and begin playback. Idempotent.
    public func start(in view: UIView) {
        guard !started else { return }
        started = true
        player.delegate = coordinator
        player.drawable = view
        player.media = VLCMedia(url: item.url)
        player.play()
        startLoadTimeout()
    }

    public var isPlaying: Bool { player.isPlaying }

    public func togglePlayPause() {
        if player.isPlaying { player.pause() } else { player.play() }
    }

    /// Relative seek in seconds.
    public func seek(by seconds: Double) {
        guard duration > 0 else { return }
        let target = min(max(0, position + seconds), duration)
        player.position = Float(target / duration)
    }

    public func seek(toFraction fraction: Double) {
        player.position = Float(min(1, max(0, fraction)))
    }

    public func teardown() {
        reportProgress()
        loadTimeout?.cancel()
        player.delegate = nil
        player.stop()
    }

    // MARK: - Delegate callbacks (hopped to MainActor)

    fileprivate func stateChanged() {
        switch player.state {
        case .playing:
            loadTimeout?.cancel()
            state = .playing
            seekToResumeIfNeeded()
        case .paused:
            state = .paused
        case .buffering, .opening:
            if state != .playing { state = .loading }
        case .error:
            fail(.streamUnavailable)
        case .stopped, .ended:
            handleEnded()
        default:
            break
        }
    }

    fileprivate func timeChanged() {
        position = Double(player.time?.intValue ?? 0) / 1000
        let length = player.media?.length?.intValue ?? 0
        if length > 0 { duration = Double(length) / 1000 }
        reportProgress()
    }

    // MARK: - Helpers

    private func startLoadTimeout() {
        loadTimeout?.cancel()
        loadTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, let self, self.state == .loading else { return }
            self.fail(.streamUnavailable)
        }
    }

    private func seekToResumeIfNeeded() {
        guard !hasSeekedToResume, !item.isLive, let resumeAt = item.resumeAt, resumeAt > 1 else { return }
        hasSeekedToResume = true
        // `time` is read-only on VLCMediaPlayer; jump relative from the start.
        player.jumpForward(Int32(resumeAt))
    }

    private func reportProgress() {
        guard !item.isLive, duration > 0, position > 0 else { return }
        onProgress(item, position, duration)
    }

    private func handleEnded() {
        guard !item.isLive else { return }
        if duration > 0 { onProgress(item, duration, duration) }
        onFinished?()
    }

    private func fail(_ error: ProviderError) {
        loadTimeout?.cancel()
        state = .failed(error)
        AppLog.player.error("VLC playback failed for \(self.item.id.rawValue, privacy: .public).")
    }

    private final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        weak var owner: VLCPlayerModel?
        init(owner: VLCPlayerModel) { self.owner = owner }

        // VLCKit's delegate thread isn't contractually main — always hop.
        func mediaPlayerStateChanged(_ aNotification: Notification!) {
            Task { @MainActor [weak owner] in owner?.stateChanged() }
        }
        func mediaPlayerTimeChanged(_ aNotification: Notification!) {
            Task { @MainActor [weak owner] in owner?.timeChanged() }
        }
    }
}
