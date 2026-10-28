import SwiftUI
import UIKit

@main
struct MotoCarPlayApp: App {
    init() {
        // 高德 Key + 隐私合规，必须在任何地图/搜索对象创建之前
        AMapConfig.setup()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
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
