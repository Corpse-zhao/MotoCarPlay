import SwiftUI

@main
struct MotoCarPlayApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
        }
    }
}
