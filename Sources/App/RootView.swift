import SwiftUI

/// Top-level tab navigation. Only Home is built in M0; the other tabs show a
/// styled "coming soon" placeholder so the product shape is visible.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    enum Tab: Hashable {
        case home, liveTV, guide, movies, series, search, settings
    }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            ComingSoonView(feature: "Live TV", milestone: "M2")
                .tabItem { Label("Live TV", systemImage: "tv") }
                .tag(Tab.liveTV)

            ComingSoonView(feature: "TV Guide", milestone: "M2")
                .tabItem { Label("Guide", systemImage: "calendar") }
                .tag(Tab.guide)

            ComingSoonView(feature: "Movies", milestone: "M3")
                .tabItem { Label("Movies", systemImage: "film") }
                .tag(Tab.movies)

            ComingSoonView(feature: "Series", milestone: "M3")
                .tabItem { Label("Series", systemImage: "rectangle.stack") }
                .tag(Tab.series)

            ComingSoonView(feature: "Search", milestone: "M4")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            ComingSoonView(feature: "Settings", milestone: "M6")
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .appThemeBackground()
    }
}

struct ComingSoonView: View {
    let feature: String
    let milestone: String

    var body: some View {
        EmptyStateView(
            icon: "hammer",
            title: "\(feature) is on the way",
            message: "This screen arrives in milestone \(milestone). The foundation it needs — domain models, normalization, repository — is already in place."
        )
        .appThemeBackground()
    }
}
