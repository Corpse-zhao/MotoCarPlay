import Foundation

/// App ↔ MCTouchHelper tweak 的桥。
/// App（TrollStore，全效力权限）把归一化坐标写到 /var/mobile/Documents/MCTouchHelper/config.plist，
/// 再发 Darwin 通知 com.corpsezhao.motocarplay.gesture；
/// tweak（注入 SpringBoard，HID 权限完整）收到通知后模拟"状态栏右区左滑"手势，
/// 由用户配置好的 SquidGesture 动作执行"在 fv 浮窗中打开汽水音乐"。
enum MCGestureBridge {
    static let notifyName = "com.corpsezhao.motocarplay.gesture"
    static let configDir = "/var/mobile/Documents/MCTouchHelper"
    static let configFile = configDir + "/config.plist"

    // 默认归一化坐标：状态栏右区 (右侧 14%) 向左滑到 62% 处
    static let defaultX0: Float = 0.86
    static let defaultY0: Float = 0.05
    static let defaultX1: Float = 0.62
    static let defaultY1: Float = 0.05

    /// 写配置 + 发通知，返回是否两条都成功
    @discardableResult
    static func sendSwipe(x0: Float = defaultX0, y0: Float = defaultY0,
                          x1: Float = defaultX1, y1: Float = defaultY1) -> Bool {
        let wrote = writeConfig(x0: x0, y0: y0, x1: x1, y1: y1)
        postNotification()
        return wrote
    }

    @discardableResult
    static func writeConfig(x0: Float, y0: Float, x1: Float, y1: Float) -> Bool {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configDir) {
            do {
                try fm.createDirectory(atPath: configDir, withIntermediateDirectories: true)
            } catch {
                NSLog("[MCGestureBridge] mkdir failed: \(error)")
                return false
            }
        }
        let cfg: NSDictionary = [
            "x0": x0, "y0": y0, "x1": x1, "y1": y1,
            "updated": Date().timeIntervalSince1970,
        ]
        let ok = cfg.write(toFile: configFile, atomically: true)
        NSLog("[MCGestureBridge] writeConfig -> \(configFile): \(ok)")
        return ok
    }

    /// 发 Darwin 通知（沙盒 App 允许 post）
    static func postNotification() {
        let name = CFNotificationName(rawValue: notifyName as CFString)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             name, nil, nil, true)
        NSLog("[MCGestureBridge] posted \(notifyName)")
    }
}
