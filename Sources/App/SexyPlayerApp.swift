import SwiftUI

@main
struct SexyPlayerApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .task { await environment.bootstrap() }
        }
    }
}
