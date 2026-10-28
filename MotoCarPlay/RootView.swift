import SwiftUI

/// 两页结构：左页 = 地图主界面，右页 = 多功能页（CarPlay 图标网格）
struct RootView: View {
    @State private var showApps = false
    @State private var searchRequested = false
    @State private var showPhone = false
    @State private var showMusic = false
    @State private var showSettings = false

    /// 显示系统状态栏（给"顶部状态栏左滑"这类手势插件留出触摸区）
    @AppStorage("showStatusBar") private var showStatusBar = false
    @StateObject private var toast = ToastCenter.shared

    var body: some View {
        ZStack {
            MapDashboardView(searchRequested: $searchRequested) {
                withAnimation(.easeOut(duration: 0.22)) { showApps = true }
            }

            if showApps {
                AppsPageView(
                    onMap: { withAnimation(.easeOut(duration: 0.22)) { showApps = false } },
                    onNavigate: {
                        withAnimation(.easeOut(duration: 0.18)) { showApps = false }
                        searchRequested = true
                    },
                    onPhone: { showPhone = true },
                    onMusic: { showMusic = true },
                    onSettings: { showSettings = true },
                    onSwipeBack: { withAnimation(.easeOut(duration: 0.22)) { showApps = false } }
                )
                .transition(.move(edge: .leading))
                .zIndex(1)
            }

            // 轻提示（浮窗打开汽水时的反馈）
            if let message = toast.message {
                VStack {
                    Spacer(minLength: 0)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(Color.black.opacity(0.85)))
                        .padding(.bottom, 56)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
                .zIndex(3)
            }
        }
        .statusBar(hidden: !showStatusBar)
        .persistentSystemOverlays(showStatusBar ? .automatic : .hidden)
        .onAppear { LocationProvider.shared.start() }
        .fullScreenCover(isPresented: $showPhone) { PhoneView() }
        .fullScreenCover(isPresented: $showMusic) { MusicView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}
