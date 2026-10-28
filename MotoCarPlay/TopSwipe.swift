import SwiftUI

// MARK: - 全局轻提示

/// 跨页面的轻提示（不抢焦点、不影响点击）
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published private(set) var message: String?
    private var dismissWork: DispatchWorkItem?

    func show(_ text: String, seconds: Double = 2.6) {
        dismissWork?.cancel()
        withAnimation(.easeOut(duration: 0.18)) { message = text }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeIn(duration: 0.25)) { self?.message = nil }
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

// MARK: - 顶部右角左滑

/// 顶部右侧「左滑」热区：按浮窗插件的方式拉起汽水音乐。
///
/// 为什么自己做手势而不是全靠插件：
/// 插件要求系统状态栏存在才认得这块区域，而横屏全屏 App 里状态栏一般被隐藏，
/// 插件根本收不到顶部那片触摸。这里自己识别一次，命中后仍然走
/// FloatingLauncher（打开汽水 + 通知 floatingView 浮窗），效果对齐插件。
///
/// 放在地图层与待机浮层之间（见 MapDashboardView），所以不会挡到右上角
/// 的图标按钮——按钮在它上层，点击照旧。
struct TopRightSwipeLauncher: View {
    private static var lastFire = Date.distantPast

    /// 热区尺寸：右上角 340×104，约等于"电池那一片"
    private let zoneWidth: CGFloat = 340
    private let zoneHeight: CGFloat = 104

    var body: some View {
        Color.black.opacity(0.001)
            .frame(width: zoneWidth, height: zoneHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        // 只认「明显往左、几乎不上下」的一划
                        guard dx < -50, abs(dy) < 70 else { return }
                        fire()
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .ignoresSafeArea()
    }

    private func fire() {
        let now = Date()
        guard now.timeIntervalSince(TopRightSwipeLauncher.lastFire) > 1.2 else { return }
        TopRightSwipeLauncher.lastFire = now

        guard FloatingLauncher.floatingEnabled else {
            ToastCenter.shared.show("浮窗开关已关闭：设置 → 音乐 → 浮窗打开汽水")
            return
        }
        ToastCenter.shared.show("正在浮窗打开汽水音乐…")
        FloatingLauncher.openQishui { msg in ToastCenter.shared.show(msg) }
    }
}
