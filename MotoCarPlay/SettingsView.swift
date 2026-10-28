import SwiftUI
import Contacts

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("musicSource") private var musicSourceRaw = MusicSource.apple.rawValue
    @AppStorage("navTarget") private var navTargetRaw = NavTarget.amap.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                Wallpaper()
                List {
                    Section("导航") {
                        Picker("默认导航", selection: $navTargetRaw) {
                            ForEach(NavTarget.allCases) { target in
                                Text(target.title).tag(target.rawValue)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()

                        Text(navTargetSubtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))

                        if !NavTarget.amap.isInstalled {
                            Text("检测到未安装高德地图，选中的目的地会改用内置地图。")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }

                    Section("音乐") {
                        Picker("播放器", selection: $musicSourceRaw) {
                            ForEach(MusicSource.allCases) { source in
                                Text(source.title).tag(source.rawValue)
                            }
                        }
                        Text("Apple Music 可在本 App 内直接显示与切歌；其他播放器受系统限制，只能唤起 App，控制请用耳机线控或 Siri。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Section("显示") {
                        Toggle("屏幕常亮（骑行推荐开启）", isOn: $keepScreenOn)
                            .tint(Theme.accent)
                        Text("界面固定横屏，速度显示在右上角与导航页横幅里。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Section("权限") {
                        HStack {
                            Text("通讯录")
                            Spacer()
                            Text(contactsStatus)
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Text("电话页需要通讯录权限才能列出联系人；去 设置 → 隐私与安全性 → 通讯录 管理。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MotoCarPlay v0.2.0")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                            Text("自建车机 · 横屏 CarPlay 风格界面")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.clear)
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

    private var navTargetSubtitle: String {
        (NavTarget(rawValue: navTargetRaw) ?? .amap).subtitle
    }

    private var contactsStatus: String {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return "已允许"
        case .denied: return "已拒绝"
        case .restricted: return "受限制"
        case .notDetermined: return "未请求"
        @unknown default: return "未知"
        }
    }
}
