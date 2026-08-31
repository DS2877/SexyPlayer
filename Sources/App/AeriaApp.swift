import SwiftUI

@main
struct AeriaApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .task {
                    await environment.applyPreferences()
                    await environment.bootstrap()
                }
                .onOpenURL { environment.open($0) }
        }
    }
}
