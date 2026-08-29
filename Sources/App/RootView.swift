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
            } else if isPreparing {
                ZStack {
                    Palette.canvas.ignoresSafeArea()
                    PreparingView()
                        .padding(Metrics.screenMargin)
                        .frame(maxWidth: 1100)
                }
            } else {
                tabs
            }
        }
        .animation(.easeInOut(duration: 0.3), value: environment.needsProviderSetup)
        .animation(.easeInOut(duration: 0.3), value: isPreparing)
    }

    /// First catalog load for a freshly-activated provider — show the checklist
    /// full-screen rather than the tab bar over empty screens.
    private var isPreparing: Bool {
        guard !environment.hasLoadedOnce else { return false }
        if case .loading = environment.loadState { return true }
        return false
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            LiveTVBrowseView()
                .tabItem { Label("Live TV", systemImage: "tv") }
                .tag(Tab.liveTV)

            ComingSoonView(feature: "TV Guide", milestone: "the next milestone")
                .tabItem { Label("Guide", systemImage: "calendar") }
                .tag(Tab.guide)

            VODBrowseView(kind: .movies)
                .tabItem { Label("Movies", systemImage: "film") }
                .tag(Tab.movies)

            VODBrowseView(kind: .series)
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
