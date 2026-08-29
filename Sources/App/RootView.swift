import SwiftUI

/// Top-level navigation. Runs the onboarding sequence (add provider → prepare →
/// personalize) the first time, then the tabbed app.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    enum Tab: Hashable {
        case home, liveTV, guide, movies, series, search, settings
    }
    enum OnboardingStage: Equatable { case addProvider, preparing, personalize }

    @State private var selection: Tab = .home
    @State private var stage: OnboardingStage?
    @State private var decidedInitialStage = false

    var body: some View {
        Group {
            switch stage {
            case .addProvider:
                ProviderSetupView(onProviderReady: { stage = .preparing })
                    .transition(.opacity)
            case .preparing:
                fullScreen {
                    LibraryLoadingView(
                        showStartButton: true,
                        onStart: advanceFromPreparing,
                        onRetry: {
                            Task {
                                if let id = environment.providers.activeID,
                                   id != ProviderStore.demoID {
                                    await environment.removeProvider(id)
                                }
                                stage = .addProvider
                            }
                        }
                    )
                }
            case .personalize:
                PersonalizeView(mode: .onboarding, onDone: { stage = nil })
                    .transition(.opacity)
            case nil:
                if coldLoadingWithoutOnboarding {
                    fullScreen { LibraryLoadingView() }
                } else {
                    tabs
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stage)
        .task {
            guard !decidedInitialStage else { return }
            decidedInitialStage = true
            if environment.needsProviderSetup {
                stage = .addProvider
            } else if !environment.preferences.hasOnboarded {
                stage = .preparing
            }
        }
        .onChange(of: environment.needsProviderSetup) { _, needs in
            if needs { stage = .addProvider }
        }
    }

    /// Returning user, no cache — cover the tab bar with the checklist until the
    /// library is ready, then drop straight into the app.
    private var coldLoadingWithoutOnboarding: Bool {
        guard environment.preferences.hasOnboarded, !environment.hasLoadedOnce else { return false }
        if case .loading = environment.loadState { return true }
        return false
    }

    private func advanceFromPreparing() {
        stage = environment.preferences.hasOnboarded ? nil : .personalize
    }

    private func fullScreen<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            content()
                .frame(maxWidth: 1000)
                .padding(Metrics.screenMargin)
        }
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
