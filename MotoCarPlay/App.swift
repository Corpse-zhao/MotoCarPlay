import SwiftUI
import UIKit

@main
struct MotoCarPlayApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .onAppear { Orientation.lockLandscape() }
        }
    }
}

enum Orientation {
    static func lockLandscape() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    }
}
