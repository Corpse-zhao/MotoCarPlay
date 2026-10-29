import UIKit
import Foundation
import CoreFoundation

/// 拉起汽水音乐（尽量配合分屏插件 floatingView 以浮窗方式打开）。
///
/// 逆向结论（com.be-huge.floating-view 1.5.9 dylib）：
/// - 主体只注入 com.apple.springboard，没有注册 URL Scheme
/// - FVNotificationCenter 是它的事件总线，动作通知名以 fv_ 开头：
///   fv_openFloatingView / fv_openFloatingView_toSide / fv_toggleMainFloatingAppDisplay /
///   fv_closeMainFloatingApp / fv_openFloatingView_lastRun
///   （`com.be-huge.floating-view.shortcuts` 只是桌面长按快捷菜单那条链路，v0.6.2 发它没反应）
///
/// 拉起顺序（v0.6.3 修正）：
/// 1. **按 bundle id 精确拉起**（com.soda.music 优先）—— 唯一不会开错 App 的方式
/// 2. 打开成功后 post fv_openFloatingView_lastRun + fv_openFloatingView，请求浮窗展示
/// ⚠️ 绝不能放 snssdk1128:// —— 那是抖音（同属字节），v0.6.0 就是这么把抖音打开了的。
enum FloatingLauncher {
    static let enabledKey = "moto.floating.qishui.enabled"
    /// floatingView 的动作通知（逆向 1.5.9 dylib 得出：FVNotificationCenter 事件总线，fv_ 前缀）
    /// - fv_openFloatingView_lastRun：打开「上次浮窗运行的 App」
    /// - fv_openFloatingView：打开浮窗
    /// - fv_toggleMainFloatingAppDisplay：显示/隐藏主浮窗（不发，怕和打开动作相互抵消）
    /// - fv_closeMainFloatingApp：关闭主浮窗（不需要）
    private static let fvActionMessages = [
        "fv_openFloatingView_lastRun",
        "fv_openFloatingView",
        "fv_openFloatingView_toSide",
        "fv_toggleMainFloatingAppDisplay",
    ]
    /// 汽水音乐的 bundle id 候选：iOS 侧一般是 com.soda.music，安卓/部分版本是 com.luna.music。
    /// 不猜，逐个试，谁打开了算谁的。
    static let qishuiBundleIDs = ["com.soda.music", "com.luna.music"]
    /// 只保留汽水自己的 scheme（未验证的 snssdk1128 / luna 已删除，避免再开错 App）
    private static let qishuiSchemes = ["qishui://"]

    static var floatingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// 手势模式：点音乐 = 发通知给 MCTouchHelper tweak（注入 SpringBoard）模拟"状态栏右区左滑"，
    /// 交给 SquidGesture 执行"在 fv 浮窗中打开"。需要先安装 MCTouchHelper deb。
    static var gestureLaunchEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: gestureKey) == nil { return false }
            return UserDefaults.standard.bool(forKey: gestureKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: gestureKey) }
    }
    static let gestureKey = "moto.gesture.launch"

    /// 点一下 / 顶部右角左滑 = 你长按 2.5 秒锁屏键的效果：打开汽水音乐
    /// - Parameter failure: 打不开时回调原因（界面用来提示，避免"点了没反应"）
    static func openQishui(failure: @escaping (String) -> Void) {
        // 0) 手势模式：写坐标 + 发 Darwin 通知，由 MCTouchHelper tweak（SpringBoard 内）
        //    模拟"状态栏右区左滑"，让 SquidGesture 执行"在 fv 浮窗中打开"。
        if gestureLaunchEnabled {
            MCGestureBridge.sendSwipe()
            return
        }

        // 1) 按 bundle id 精确拉起（候选逐个试，成功即返回）
        for id in qishuiBundleIDs where openByBundleID(id) {
            afterOpenFloating()
            return
        }

        // 2) 已安装列表里模糊找一次（bundle id 变体 / 企业签名版）
        if let alt = findQishuiBundleID(), !qishuiBundleIDs.contains(alt), openByBundleID(alt) {
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
        // 汽水切前台需要一点时间，两轮广播：0.7s 起、2.0s 补
        for delay in [0.7, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { broadcast() }
        }
    }

    /// 多通道广播。
    /// floatingView 的 FVNotificationCenter 既可能挂 Darwin 通知，也可能挂分布式通知，
    /// 沙盒 App 只有这两条路可走，所以同名消息两个通道都发一遍（收不到的那条无副作用）。
    private static func broadcast() {
        for name in fvActionMessages {
            postDarwin(name)
            postDistributed(name)
        }
    }

    /// 发 Darwin 通知（沙盒 App 允许 post，不需要额外权限）
    private static func postDarwin(_ name: String) {
        let notificationName = CFNotificationName(rawValue: name as CFString)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             notificationName,
                                             nil, nil, true)
    }

    /// 发分布式通知（跨进程，四个参数得走 runtime——iOS 的 Swift overlay 没暴露这个类）
    private static func postDistributed(_ name: String) {
        guard let cls = NSClassFromString("NSDistributedNotificationCenter") as? NSObject.Type,
              let center = cls.perform(NSSelectorFromString("defaultCenter"))?
                .takeUnretainedValue() as? NSObject else { return }

        let sel = NSSelectorFromString("postNotificationName:object:userInfo:deliverImmediately:")
        if center.responds(to: sel) {
            typealias Fn4 = @convention(c) (AnyObject, Selector, NSString, AnyObject?, NSDictionary?, Bool) -> Void
            let fn = unsafeBitCast(center.method(for: sel), to: Fn4.self)
            fn(center, sel, name as NSString, nil, nil, true)
            return
        }
        let sel3 = NSSelectorFromString("postNotificationName:object:userInfo:")
        if center.responds(to: sel3) {
            typealias Fn3 = @convention(c) (AnyObject, Selector, NSString, AnyObject?, NSDictionary?) -> Void
            let fn = unsafeBitCast(center.method(for: sel3), to: Fn3.self)
            fn(center, sel3, name as NSString, nil, nil)
        }
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

    /// 找汽水音乐的 bundle id：候选精确匹配 → 名字含「汽水」→ bundle id 含 soda / luna
    static func findQishuiBundleID() -> String? {
        let apps = installedApps()
        for id in qishuiBundleIDs where apps.contains(where: { $0.id == id }) {
            return id
        }
        if let hit = apps.first(where: { $0.name.contains("汽水") }) { return hit.id }
        if let hit = apps.first(where: { $0.id.lowercased().contains("soda") }) { return hit.id }
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
            lines.append("匹配到汽水音乐：\(name)（\(id)）")
        } else {
            lines.append("没匹配到汽水音乐")
        }

        for id in qishuiBundleIDs {
            lines.append("\(id)：\(apps.contains(where: { $0.id == id }) ? "已安装" : "不在列表")")
        }

        for scheme in qishuiSchemes {
            let ok = URL(string: scheme).map { UIApplication.shared.canOpenURL($0) } ?? false
            lines.append("scheme \(scheme)：\(ok ? "系统认得" : "系统不认")")
        }
        return lines.joined(separator: "\n")
    }
}
