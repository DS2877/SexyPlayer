import SwiftUI

/// Value-based navigation targets. Pushed onto a `NavigationStack` path.
public enum AppRoute: Hashable, Sendable {
    case movie(CatalogID)
    case series(CatalogID)
    case channel(CatalogID)
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
