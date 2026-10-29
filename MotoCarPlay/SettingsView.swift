import SwiftUI
import Contacts

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepScreenOn") private var keepScreenOn = true

    var body: some View {
        NavigationStack {
            ZStack {
                Wallpaper()
                List {
                    Section("显示") {
                        Toggle("屏幕常亮（骑行推荐开启）", isOn: $keepScreenOn)
                            .tint(Theme.accent)
                    }

                    Section("权限") {
                        HStack {
                            Text("定位")
                            Spacer()
                            Text(locationStatus)
                                .foregroundColor(.white.opacity(0.55))
                        }
                        HStack {
                            Text("通讯录")
                            Spacer()
                            Text(contactsStatus)
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Text("定位用于车速、方向与导航；通讯录用于电话页联系人列表。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MotoCarPlay v0.8.0")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                            Text("地图 + 电话 · 精简版")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: keepScreenOn) { on in
                UIApplication.shared.isIdleTimerDisabled = on
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = keepScreenOn
            }
        }
        .preferredColorScheme(.dark)
    }

    private var contactsStatus: String {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return "已允许"
        case .limited: return "部分允许"
        case .denied: return "已拒绝"
        case .restricted: return "受限制"
        case .notDetermined: return "未请求"
        @unknown default: return "未知"
        }
    }

    private var locationStatus: String {
        switch LocationProvider.shared.manager.authorizationStatus {
        case .authorizedWhenInUse: return "使用期间"
        case .authorizedAlways: return "始终"
        case .denied: return "已拒绝"
        case .restricted: return "受限制"
        case .notDetermined: return "未请求"
        @unknown default: return "未知"
        }
    }
}
