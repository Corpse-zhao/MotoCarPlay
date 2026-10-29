import SwiftUI
import Contacts

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("musicSource") private var musicSourceRaw = MusicSource.qq.rawValue
    @AppStorage(FloatingLauncher.enabledKey) private var floatingQishui = true
    @AppStorage(FloatingLauncher.gestureKey) private var gestureLaunch = true
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
                        Toggle("点音乐=模拟状态栏左滑（交给手势插件）", isOn: $gestureLaunch)
                            .tint(Theme.accent)
                        Text("开启后：点「音乐」方块或地图页右上角左滑，会模拟一次「状态栏右侧向左滑」的系统触摸，交给你的手势插件执行「在 fv 浮窗中打开」。需同时开启下方「显示系统状态栏」。若点音乐没反应，关掉此开关回到 App 直接拉起（全屏）。")
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
                            Text("MotoCarPlay v0.7.0")
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
