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
                .onAppear { Orientation.apply() }
        }
    }
}

/// 屏幕方向：默认锁定横屏（CarPlay 风格），设置里可切竖屏
enum Orientation {
    static let portraitKey = "portraitMode"

    static var isPortrait: Bool {
        UserDefaults.standard.bool(forKey: portraitKey)
    }

    static func apply() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let mask: UIInterfaceOrientationMask = isPortrait ? .portrait : .landscapeRight
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }
}
