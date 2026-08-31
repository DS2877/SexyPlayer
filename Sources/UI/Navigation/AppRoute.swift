import SwiftUI

/// Value-based navigation targets. Pushed onto a `NavigationStack` path.
public enum AppRoute: Hashable, Sendable, Identifiable {
    case movie(CatalogID)
    case series(CatalogID)
    case channel(CatalogID)

    public var id: String {
        switch self {
        case .movie(let x):   return "movie:\(x.rawValue)"
        case .series(let x):  return "series:\(x.rawValue)"
        case .channel(let x): return "channel:\(x.rawValue)"
        }
    }

    /// Parse an `aeria://<kind>/<percent-encoded CatalogID>` deep link.
    public init?(deepLink url: URL) {
        guard url.scheme == "aeria" else { return nil }
        let kind = url.host ?? url.pathComponents.first { $0 != "/" } ?? ""
        let rawID = url.pathComponents.last(where: { $0 != "/" })?
            .removingPercentEncoding ?? ""
        guard !rawID.isEmpty else { return nil }
        let cid = CatalogID(rawValue: rawID)
        switch kind {
        case "movie":   self = .movie(cid)
        case "series":  self = .series(cid)
        case "channel": self = .channel(cid)
        default:        return nil
        }
    }
}

/// Resolves a route to its screen. Attached once per `NavigationStack`.
struct RouteDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .movie(let id):   MovieDetailView(movieID: id)
            case .series(let id):  SeriesDetailView(seriesID: id)
            case .channel(let id): ChannelDetailView(channelID: id)
            }
        }
    }
}

extension View {
    func appRouteDestinations() -> some View { modifier(RouteDestinations()) }
}
