import SwiftUI
import Contacts

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("musicSource") private var musicSourceRaw = MusicSource.qq.rawValue
    @AppStorage(FloatingLauncher.enabledKey) private var floatingQishui = true
    @AppStorage("showStatusBar") private var showStatusBar = false
    @State private var showDiag = false
    @State private var diagText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Wallpaper()
                List {
                    Section("音乐") {
                        Picker("默认音乐源", selection: $musicSourceRaw) {
                            ForEach(MusicSource.allCases) { source in
                                Text(source.title).tag(source.rawValue)
                            }
                        }
                        Toggle("浮窗打开汽水（配合分屏插件）", isOn: $floatingQishui)
                            .tint(Theme.accent)
                        Text("开启后：点多功能页的「音乐」方块，或者在地图页顶部右角往左滑，都会直接拉起汽水音乐，并给分屏插件 floatingView 发浮窗指令（对应它内部的 fv_openFloatingView_lastRun）。提示：先用 floatingView 手动浮窗打开一次汽水，建立「上次浮窗运行」记录后，这里触发会更稳。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                        Button {
                            diagText = FloatingLauncher.diagnosis()
                            showDiag = true
                        } label: {
                            HStack {
                                Text("诊断汽水音乐")
                                Spacer()
                                Image(systemName: "stethoscope")
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                    }

                    Section("显示") {
                        Toggle("屏幕常亮（骑行推荐开启）", isOn: $keepScreenOn)
                            .tint(Theme.accent)
                        Toggle("显示系统状态栏（配合状态栏手势插件）", isOn: $showStatusBar)
                            .tint(Theme.accent)
                        Text("开启后顶部露出系统状态栏，状态栏区域（电池那一块）重新归 SpringBoard 管辖，手势插件就能在 App 内用「顶部左滑」等状态栏手势把汽水开成浮窗。注意：带刘海的机型横屏时系统不显示状态栏，这种情况下用「地图页顶部右角左滑」这条自带手势即可。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
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
                            Text("MotoCarPlay v0.6.4")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                            Text("地图主界面 + 多功能页 · 全部功能在 App 内完成")
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
            .onChange(of: showStatusBar) { on in
                StatusBar.apply(visible: on)
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = keepScreenOn
                StatusBar.apply(visible: showStatusBar)
            }
            .alert("汽水音乐诊断", isPresented: $showDiag) {
                Button("好", role: .cancel) {}
            } message: {
                Text(diagText)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var contactsStatus: String {        switch CNContactStore.authorizationStatus(for: .contacts) {
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
