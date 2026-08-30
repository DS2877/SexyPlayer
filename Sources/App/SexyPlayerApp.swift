import SwiftUI

@main
struct SexyPlayerApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .buttonBorderShape(.capsule)          // pill-shaped CTAs, app-wide
                .task {
                    await environment.applyPreferences()
                    await environment.bootstrap()
                }
        }
    }
}
