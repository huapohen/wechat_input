import SwiftUI

@main
struct WeTypeCloneApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(Theme.accentDark)
        }
    }
}
