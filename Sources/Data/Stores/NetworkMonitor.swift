import Foundation
import Network
import Observation

/// Tracks basic network reachability so the UI can warn when the Apple TV is
/// offline (every screen here needs the network — the provider, TMDB, streams).
@MainActor
@Observable
public final class NetworkMonitor {

    /// `true` until the path monitor says otherwise, so a brief startup gap
    /// never flashes an "offline" banner.
    public private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "se.aeriaplus.network-monitor")
    @ObservationIgnored private var started = false

    public init() {}

    public func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: queue)
    }
}
