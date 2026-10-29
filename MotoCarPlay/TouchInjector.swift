import Foundation
import Darwin
import UIKit

/// 模拟一次"状态栏右侧区域向左滑动"的系统触摸。
///
/// 原理：TrollStore 安装的 App，内嵌的 entitlements 是全效力的。
/// 给 IPA 嵌入 HID 权限（com.apple.hid.manager.user-access-device 等）后，
/// 可以通过私有 IOKit API（IOHIDEventSystemClient）向 backboardd 注入
/// digitizer 触摸事件——backboardd 会把它当成真实手指。
/// 触摸落在状态栏区域时由 SpringBoard 进程接收，于是你配置的
/// 手势插件（SquidGesture Pro）就能识别并执行"在 fv 浮窗中打开"。
///
/// 注意：需要「显示系统状态栏」开启，状态栏窗口存在时触摸才会
/// 交给 SpringBoard 而不是我们自己的 App。
enum TouchInjector {
    /// 最近一次注入时间（防止注入的触摸落回自己 App 时造成循环触发）
    static var lastInjectAt = Date.distantPast
    static var isInjecting = false

    /// 在状态栏右侧区域向左滑一下
    /// - Returns: 是否成功构造并派发了 HID 事件（不代表插件一定识别）
    @discardableResult
    static func swipeLeftOnStatusBarRight() -> Bool {
        guard !isInjecting else { return false }
        isInjecting = true
        lastInjectAt = Date()
        defer { isInjecting = false }

        guard let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            return false
        }
        typealias CreateClientFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        typealias CreateFingerFn = @convention(c) (
            UnsafeMutableRawPointer?, UInt64,                 // allocator, timestamp
            UInt32, UInt32, UInt32, UInt32,                   // index, identity, eventMask, buttonMask
            Float, Float, Float,                              // x, y, z
            Float, Float,                                     // tipPressure, twist
            Bool, Bool, UInt32                                // range, touch, options
        ) -> UnsafeMutableRawPointer?
        typealias DispatchFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
        typealias SetSenderFn = @convention(c) (UnsafeMutableRawPointer?, UInt64) -> Void
        typealias ScheduleFn = @convention(c) (UnsafeMutableRawPointer?, CFRunLoop?, CFString?) -> Void

        guard let createClientSym = dlsym(iokit, "IOHIDEventSystemClientCreate"),
              let createFingerSym = dlsym(iokit, "IOHIDEventCreateDigitizerFingerEvent"),
              let dispatchSym = dlsym(iokit, "IOHIDEventSystemClientDispatchEvent") else {
            return false
        }
        let createClient = unsafeBitCast(createClientSym, to: CreateClientFn.self)
        let createFinger = unsafeBitCast(createFingerSym, to: CreateFingerFn.self)
        let dispatch = unsafeBitCast(dispatchSym, to: DispatchFn.self)
        let setSender: SetSenderFn? = unsafeBitCast(dlsym(iokit, "IOHIDEventSetSenderID"), to: SetSenderFn?.self)
        let schedule: ScheduleFn? = unsafeBitCast(dlsym(iokit, "IOHIDEventSystemClientScheduleWithRunLoop"), to: ScheduleFn?.self)

        guard let client = createClient(nil) else { return false }
        if let schedule {
            let mode = "kCFRunLoopDefaultMode" as CFString
            schedule(client, CFRunLoopGetMain(), Unmanaged.passUnretained(mode).toOpaque())
        }

        // 目标：状态栏右侧"电池那一片"，向左滑
        let screen = UIScreen.main.bounds
        let startX = screen.width * 0.86
        let endX = screen.width * 0.62
        let y = min(16.0, screen.height * 0.04)
        let steps = 10

        func finger(_ mask: UInt32, _ x: CGFloat, _ y: CGFloat, _ pressure: Float, _ range: Bool, _ touch: Bool) -> Bool {
            guard let ev = createFinger(nil, mach_absolute_time(),
                                        1, 2, mask, 0,
                                        Float(x), Float(y), 0,
                                        pressure, 0,
                                        range, touch, 0) else { return false }
            if let setSender { setSender(ev, 0xdefaced) }
            dispatch(client, ev)
            return true
        }

        // 按下
        guard finger(0b011, startX, y, 1.0, true, true) else { return false }
        usleep(28_000)
        // 移动
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let x = startX + (endX - startX) * CGFloat(t)
            guard finger(0b110, x, y, 1.0, true, true) else { return false }
            usleep(18_000)
        }
        // 抬起
        _ = finger(0b011, endX, y, 0.0, false, false)
        return true
    }
}
