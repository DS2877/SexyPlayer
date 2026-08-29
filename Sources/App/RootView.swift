import SwiftUI

/// Top-level flow. Runs the onboarding sequence (add provider → prepare →
/// personalize) the first time, then hands off to the sidebar shell. The shell
/// never blocks on the library import — a status pill shows instead.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    enum OnboardingStage: Equatable { case addProvider, preparing, personalize }

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
                SidebarShell()
                    .transition(.opacity)
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
}
