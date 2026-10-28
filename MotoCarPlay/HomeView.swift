import SwiftUI

struct HomeView: View {
    @StateObject private var location = LocationProvider.shared
    @StateObject private var music = MusicProvider.shared
    @State private var showNav = false
    @State private var showMusic = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 14) {
                StatusBar(speedKmh: location.speedKmh, heading: location.heading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 顶部大车速表（骑行时最常看的数字）
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前车速")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                        Text("\(Int(location.speedKmh))")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text("km/h")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: compassSymbol)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(Theme.accent)
                        Text(compassLabel)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .frame(width: 90)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card))
                .padding(.horizontal, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        Button { showNav = true } label: {
                            BigCard(title: "导航", subtitle: "去哪里？",
                                    systemImage: "map.fill", tint: Theme.accent)
                        }
                        .buttonStyle(CardButton())

                        Button { showMusic = true } label: {
                            BigCard(title: "音乐", subtitle: music.isPlaying ? "正在播放 · \(music.title)" : "未在播放",
                                    systemImage: "music.note", tint: .pink)
                        }
                        .buttonStyle(CardButton())

                        Button {
                            if let url = URL(string: "tel://") { UIApplication.shared.open(url) }
                        } label: {
                            BigCard(title: "电话", subtitle: "用系统拨号或 Siri",
                                    systemImage: "phone.fill", tint: .green)
                        }
                        .buttonStyle(CardButton())

                        Button { showSettings = true } label: {
                            BigCard(title: "设置", subtitle: "亮度 / 关于",
                                    systemImage: "gearshape.fill", tint: Theme.warn)
                        }
                        .buttonStyle(CardButton())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear { location.start() }
        .task {
            // 等首帧渲染完再碰媒体库，避免启动期权限检查导致闪退
            try? await Task.sleep(nanoseconds: 600_000_000)
            music.start()
        }
        .fullScreenCover(isPresented: $showNav) { NavigateView() }
        .fullScreenCover(isPresented: $showMusic) { NowPlayingView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var compassSymbol: String {
        let dirs = ["arrow.up", "arrow.up.right", "arrow.right", "arrow.down.right",
                    "arrow.down", "arrow.down.left", "arrow.left", "arrow.up.left"]
        let idx = Int(((location.heading + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return dirs[(idx + 8) % 8]
    }

    private var compassLabel: String {
        let labels = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        let idx = Int(((location.heading + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return labels[(idx + 8) % 8]
    }
}

/// 触感反馈 + 按压变色，模拟 CarPlay 图标手感
struct CardButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct StatusBar: View {
    let speedKmh: Double
    let heading: Double

    var body: some View {
        HStack {
            Text(Date(), style: .time)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
            Spacer()
            if speedKmh > 2 {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("骑行中")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}
