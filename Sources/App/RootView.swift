import SwiftUI

/// Top-level navigation. Shows onboarding until a provider is configured, then
/// the tabbed app.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    enum Tab: Hashable {
        case home, liveTV, guide, movies, series, search, settings
    }

    @State private var selection: Tab = .home

    var body: some View {
        Group {
            if environment.needsProviderSetup {
                ProviderSetupView()
                    .transition(.opacity)
            } else {
                tabs
            }
        }
        .animation(.easeInOut(duration: 0.3), value: environment.needsProviderSetup)
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            ComingSoonView(feature: "Live TV", milestone: "the next milestone")
                .tabItem { Label("Live TV", systemImage: "tv") }
                .tag(Tab.liveTV)

            ComingSoonView(feature: "TV Guide", milestone: "the next milestone")
                .tabItem { Label("Guide", systemImage: "calendar") }
                .tag(Tab.guide)

            ComingSoonView(feature: "Movies", milestone: "the next milestone")
                .tabItem { Label("Movies", systemImage: "film") }
                .tag(Tab.movies)

            ComingSoonView(feature: "Series", milestone: "the next milestone")
                .tabItem { Label("Series", systemImage: "rectangle.stack") }
                .tag(Tab.series)

            ComingSoonView(feature: "Search", milestone: "the next milestone")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            SettingsView()
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
            message: "This screen arrives in \(milestone). The foundation it needs is already in place."
        )
        .appThemeBackground()
    }
}
