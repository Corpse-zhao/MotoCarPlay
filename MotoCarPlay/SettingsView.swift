import SwiftUI
import Contacts

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("musicSource") private var musicSourceRaw = MusicSource.qq.rawValue

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
                        Text("三个音乐平台都以网页版形式内嵌在本 App 内运行，首次进入需要在该页面登录一次账号。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Section("显示") {
                        Toggle("屏幕常亮（骑行推荐开启）", isOn: $keepScreenOn)
                            .tint(Theme.accent)
                        Text("界面固定横屏；地图主界面左上角显示车速与方向，右滑进入多功能页。")
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
                            Text("MotoCarPlay v0.3.0")
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
