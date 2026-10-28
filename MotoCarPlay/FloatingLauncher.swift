import UIKit
import CoreFoundation

/// 拉起汽水音乐（尽量配合分屏插件 floatingView 以浮窗方式打开）。
///
/// 逆向结论（com.be-huge.floating-view，1.5.x / 1.6.x 同架构）：
/// - 主体只注入 com.apple.springboard，没有注册 URL Scheme，沙盒 App 无法直接调它的浮窗 API
/// - 它内部有一条 Darwin 通知 `com.be-huge.floating-view.shortcuts`（桌面长按图标"浮窗打开"走这条）
///
/// 拉起顺序（v0.6.1 修正）：
/// 1. **按 bundle id 精确拉起**（com.luna.music）—— 唯一不会开错 App 的方式
/// 2. 已安装列表里按名字「汽水」/ bundle id 含 luna 模糊找一次（应对企业签名变体）
/// 3. 最后才试汽水自己的 URL scheme
/// ⚠️ 绝不能再放 snssdk1128:// —— 那是抖音（同属字节），v0.6.0 就是这么把抖音打开了的。
/// 4. 打开成功后补一条 Darwin 通知，请求插件把当前 App 转成浮窗
enum FloatingLauncher {
    static let enabledKey = "moto.floating.qishui.enabled"
    private static let floatingNotify = "com.be-huge.floating-view.shortcuts"
    private static let qishuiBundleID = "com.luna.music"
    /// 只保留汽水自己的 scheme（未验证的 snssdk1128 / luna 已删除，避免再开错 App）
    private static let qishuiSchemes = ["qishui://"]

    static var floatingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// 点一下 / 顶部右角左滑 = 你长按 2.5 秒锁屏键的效果：打开汽水音乐
    /// - Parameter failure: 打不开时回调原因（界面用来提示，避免"点了没反应"）
    static func openQishui(failure: @escaping (String) -> Void) {
        // 1) 按 bundle id 精确拉起
        if openByBundleID(qishuiBundleID) {
            afterOpenFloating()
            return
        }

        // 2) 已安装列表里模糊找一次（bundle id 变体）
        if let alt = findQishuiBundleID(), alt != qishuiBundleID, openByBundleID(alt) {
            afterOpenFloating()
            return
        }

        // 3) 最后试汽水自己的 URL scheme
        if let url = qishuiSchemes.compactMap({ URL(string: $0) })
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

        DispatchQueue.main.async {
            failure("打不开汽水音乐（设置 → 音乐 →「诊断汽水音乐」可看原因）")
        }
    }

    // MARK: - 浮窗通知

    private static func afterOpenFloating() {
        guard floatingEnabled else { return }
        // 两次：App 刚切走时 SpringBoard 可能还没把前台切到汽水，晚一点再补一发
        for delay in [0.6, 1.8] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                postDarwin(floatingNotify)
            }
        }
    }

    /// 发 Darwin 通知（沙盒 App 允许 post，不需要额外权限）
    private static func postDarwin(_ name: String) {
        let notificationName = CFNotificationName(rawValue: name as CFString)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             notificationName,
                                             nil, nil, true)
    }

    // MARK: - 私有 API（TrollStore / 越狱环境可用）

    private static func workspace() -> NSObject? {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else { return nil }
        return cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject
    }

    /// 按 bundle id 打开，返回真实结果（BOOL），不会"假装成功"
    @discardableResult
    static func openByBundleID(_ bundleID: String) -> Bool {
        guard let ws = workspace() else { return false }
        let sel = NSSelectorFromString("openApplicationWithBundleID:")
        guard ws.responds(to: sel) else { return false }
        typealias Fn = @convention(c) (AnyObject, Selector, NSString) -> Bool
        let fn = unsafeBitCast(ws.method(for: sel), to: Fn.self)
        return fn(ws, sel, bundleID as NSString)
    }

    /// 已安装 App（bundleID, 显示名）
    static func installedApps() -> [(id: String, name: String)] {
        guard let ws = workspace() else { return [] }
        let sel = NSSelectorFromString("allInstalledApplications")
        guard ws.responds(to: sel) else { return [] }
        typealias Fn = @convention(c) (AnyObject, Selector) -> NSArray?
        let fn = unsafeBitCast(ws.method(for: sel), to: Fn.self)
        guard let list = fn(ws, sel) as? [NSObject] else { return [] }
        return list.compactMap { proxy in
            let id = stringValue(proxy, "bundleIdentifier")
            guard !id.isEmpty else { return nil }
            return (id, stringValue(proxy, "localizedName"))
        }
    }

    private static func stringValue(_ obj: NSObject, _ key: String) -> String {
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel) else { return "" }
        return (obj.perform(sel)?.takeUnretainedValue() as? String) ?? ""
    }

    /// 找汽水音乐的 bundle id：精确 → 名字含「汽水」→ bundle id 含 luna
    static func findQishuiBundleID() -> String? {
        let apps = installedApps()
        if apps.contains(where: { $0.id == qishuiBundleID }) { return qishuiBundleID }
        if let hit = apps.first(where: { $0.name.contains("汽水") }) { return hit.id }
        if let hit = apps.first(where: { $0.id.lowercased().contains("luna") }) { return hit.id }
        return nil
    }

    /// 诊断文本（设置页里给用户看，'开错 App / 打不开' 时一眼定位）
    static func diagnosis() -> String {
        var lines: [String] = []
        lines.append("LSApplicationWorkspace：\(workspace() == nil ? "不可用（沙盒限制）" : "可用")")

        let apps = installedApps()
        lines.append("已安装列表：\(apps.isEmpty ? "读不到" : "\(apps.count) 个 App")")

        if let id = findQishuiBundleID() {
            let name = apps.first(where: { $0.id == id })?.name ?? "?"
            lines.append("汽水音乐：\(name)（\(id)）")
        } else {
            lines.append("汽水音乐：没有在已安装列表里匹配到")
        }

        for scheme in qishuiSchemes {
            let ok = URL(string: scheme).map { UIApplication.shared.canOpenURL($0) } ?? false
            lines.append("scheme \(scheme)：\(ok ? "系统认得" : "系统不认")")
        }
        return lines.joined(separator: "\n")
    }
}
