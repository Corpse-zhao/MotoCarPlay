import UIKit
import CoreFoundation

/// 通过分屏插件（floatingView / com.be-huge.floating-view）把汽水音乐拉起来。
///
/// 逆向结论（1.5.x/1.6.x 同架构）：
/// - 主体只注入 SpringBoard，**没有注册 URL Scheme**，沙盒 App 无法直接调它的浮窗 API
/// - 它有一条内部 Darwin 通知通道 `com.be-huge.floating-view.shortcuts`（桌面长按图标里的"浮窗打开"走这条）
/// 所以策略是：先 post 这条通知（请插件准备浮窗），再 `qishui://` 拉起汽水；
/// 若插件不认这条通知，退化成普通全屏打开 —— 效果等同于你长按锁屏键那套手势。
enum FloatingLauncher {
    static let enabledKey = "moto.floating.qishui.enabled"
    private static let floatingNotify = "com.be-huge.floating-view.shortcuts"

    /// 是否走"先通知分屏插件"的流程（默认开）
    static var floatingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// 点一下 = 你长按 2.5 秒锁屏键（打开汽水音乐，尽量浮窗）
    static func openQishui() {
        if floatingEnabled {
            postDarwin(floatingNotify)
        }
        let delay: TimeInterval = floatingEnabled ? 0.25 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            open("qishui://")
        }
    }

    /// 发 Darwin 通知（沙盒 App 允许 post，不需要额外权限）
    private static func postDarwin(_ name: String) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             name as CFString,
                                             nil, nil, true)
    }

    @discardableResult
    static func open(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        guard UIApplication.shared.canOpenURL(url) else { return false }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }
}
