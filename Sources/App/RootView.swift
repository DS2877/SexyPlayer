import SwiftUI

/// Top-level flow. Derives the onboarding step from app state (no flash on
/// launch) and lets the user click forward through it. Once past onboarding it
/// hands off to the sidebar shell, which never blocks on the library import.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    enum Stage: Equatable { case addProvider, preparing, personalize, app }

    /// Set only when the user clicks forward through a step. `nil` = derive from
    /// state.
    @State private var manualStage: Stage?

    private var stage: Stage {
        if let manualStage { return manualStage }
        if environment.needsProviderSetup { return .addProvider }
        if !environment.preferences.hasOnboarded { return .preparing }
        return .app
    }

    var body: some View {
        Group {
            switch stage {
            case .addProvider:
                ProviderSetupView(onProviderReady: { manualStage = .preparing })
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
                                manualStage = nil   // back to derived -> addProvider
                            }
                        }
                    )
                }

            case .personalize:
                PersonalizeView(mode: .onboarding, onDone: { manualStage = .app })
                    .transition(.opacity)

            case .app:
                SidebarShell()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stage)
        .onChange(of: environment.needsProviderSetup) { _, needs in
            if needs { manualStage = nil }
        }
    }

    private func advanceFromPreparing() {
        manualStage = environment.preferences.hasOnboarded ? .app : .personalize
    }

    private func fullScreen<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            content()
                .frame(maxWidth: 1000)
                .padding(Metrics.screenMargin)
        }
    }
}
