import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepScreenOn") private var keepScreenOn = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
                    Section("显示") {
                        Toggle("屏幕常亮（骑行推荐开启）", isOn: $keepScreenOn)
                            .tint(Theme.accent)
                    }
                    Section("音乐") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("当前音乐源为系统播放器")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textPrimary)
                            Text("出发前在 Apple Music / 资料库里点开歌单，回到本 App 即可控制。")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    Section("安全") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("骑行中请勿伸手操作屏幕，一切交给 Siri。")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textPrimary)
                            Text("长按手机侧键或说「嘿 Siri」即可语音导航、切歌、回消息。")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MotoCarPlay v0.1")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textSecondary)
                            Text("自建车机 · MVP 骨架，后续按需迭代")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
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
}
