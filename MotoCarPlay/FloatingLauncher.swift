import UIKit
import CoreFoundation

/// 拉起汽水音乐（尽量配合分屏插件 floatingView 以浮窗方式打开）。
///
/// 逆向结论（com.be-huge.floating-view，1.5.x / 1.6.x 同架构）：
/// - 主体只注入 SpringBoard，没有注册 URL Scheme，沙盒 App 无法直接调它的浮窗 API
/// - 它内部有一条 Darwin 通知 `com.be-huge.floating-view.shortcuts`（桌面长按图标"浮窗打开"走这条）
/// 所以策略：
/// 1. 先尝试 qishui:// 等已知 scheme（能不能开先保证）
/// 2. 打不开就退到按 bundle id 拉起（越狱/TrollStore 环境下的 LSApplicationWorkspace）
/// 3. 成功后补一条 Darwin 通知，请求插件把当前 App 转成浮窗
enum FloatingLauncher {
    static let enabledKey = "moto.floating.qishui.enabled"
    private static let floatingNotify = "com.be-huge.floating-view.shortcuts"
    private static let qishuiBundleID = "com.luna.music"

    static var floatingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// 点一下 = 你长按 2.5 秒锁屏键的效果：打开汽水音乐
    /// - Parameter failure: 打不开时回调原因（界面用来提示，避免"点了没反应"）
    static func openQishui(failure: @escaping (String) -> Void) {
        let schemes = ["qishui://", "snssdk1128://", "luna://"]
        if let url = schemes.compactMap({ URL(string: $0) })
            .first(where: { UIApplication.shared.canOpenURL($0) }) {
            UIApplication.shared.open(url, options: [:]) { ok in
                if ok {
                    afterOpenFloating()
                } else {
                    DispatchQueue.main.async { failure("系统拒绝打开汽水音乐") }
                }
            }
            return
        }
        // 兜底：按 bundle id 直接拉起（TrollStore/越狱环境常见可用）
        if openByBundleID(qishuiBundleID) {
            afterOpenFloating()
            return
        }
        DispatchQueue.main.async {
            failure("没找到汽水音乐：请确认已安装；若已安装告诉我，我换拉起方式")
        }
    }

    private static func afterOpenFloating() {
        guard floatingEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            postDarwin(floatingNotify)
        }
    }

    /// 发 Darwin 通知（沙盒 App 允许 post，不需要额外权限）
    private static func postDarwin(_ name: String) {
        let notificationName = CFNotificationName(rawValue: name as CFString)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             notificationName,
                                             nil, nil, true)
    }

    @discardableResult
    private static func openByBundleID(_ bundleID: String) -> Bool {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = cls.perform(NSSelectorFromString("defaultWorkspace"))?
                .takeUnretainedValue() as? NSObject else { return false }
        let sel = NSSelectorFromString("openApplicationWithBundleID:")
        guard workspace.responds(to: sel) else { return false }
        _ = workspace.perform(sel, with: bundleID)
        return true
    }
}
