import UIKit

/// 系统状态栏可见性。
///
/// 本 App 是横屏全屏车机界面，默认把系统状态栏藏起来（沉浸感、布局不被挤）。
/// 但"顶部状态栏左滑"这类第三方手势插件（左滑右上角电池区 → 浮窗开 App）
/// 依赖 SpringBoard 的状态栏仍然存在，否则那一片区域收不到触摸。
///
/// 所以给它一个运行时开关 `showStatusBar`：
/// - 真正的可见性由 SwiftUI 的 `.statusBar(hidden:)` 写到宿主控制器上（见 RootView）
/// - 这里只负责在开关变化后催一次外观刷新，让从设置页返回时立刻生效
/// - Info.plist 里必须 `UIViewControllerBasedStatusBarAppearance = true`，
///   否则系统会忽略视图控制器的偏好、只看 `UIStatusBarHidden`，开关就形同虚设
enum StatusBar {
    static func apply(visible: Bool) {
        refresh()
    }

    /// 立刻请求一次状态栏外观更新
    static func refresh() {
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
            guard let windows = scene?.windows else { return }
            for window in windows {
                window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }
}
