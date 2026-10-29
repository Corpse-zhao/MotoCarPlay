import SwiftUI

/// 两页结构：左页 = 地图主界面，右页 = 多功能页（CarPlay 图标网格）
struct RootView: View {
    @State private var showApps = false
    @State private var searchRequested = false
    @State private var showPhone = false
    @State private var showSettings = false

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
                    onSettings: { showSettings = true },
                    onSwipeBack: { withAnimation(.easeOut(duration: 0.22)) { showApps = false } }
                )
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onAppear { LocationProvider.shared.start() }
        .fullScreenCover(isPresented: $showPhone) { PhoneView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}
