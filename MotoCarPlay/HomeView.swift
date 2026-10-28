import SwiftUI

/// CarPlay 风格首页：状态栏 + 大图标网格 + 正在播放条 + Dock
struct HomeView: View {
    @StateObject private var location = LocationProvider.shared
    @StateObject private var music = MusicProvider.shared
    @AppStorage("musicSource") private var musicSourceRaw = MusicSource.apple.rawValue

    @State private var showNav = false
    @State private var showPhone = false
    @State private var showMusic = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Wallpaper()

            VStack(spacing: 0) {
                CarPlayStatusBar(speedKmh: location.speedKmh)
                    .padding(.horizontal, 28)
                    .padding(.top, 4)

                Spacer(minLength: 0)

                HStack(spacing: 34) {
                    AppIcon(title: "导航", symbol: "map.fill",
                            colors: [Color(red: 0.20, green: 0.72, blue: 0.45),
                                     Color(red: 0.10, green: 0.48, blue: 0.30)],
                            size: 100) { showNav = true }

                    AppIcon(title: "电话", symbol: "phone.fill",
                            colors: [Color(red: 0.30, green: 0.85, blue: 0.42),
                                     Color(red: 0.10, green: 0.60, blue: 0.28)],
                            size: 100) { showPhone = true }

                    AppIcon(title: "音乐", symbol: "music.note",
                            colors: [Color(red: 0.98, green: 0.32, blue: 0.42),
                                     Color(red: 0.80, green: 0.12, blue: 0.32)],
                            size: 100) { showMusic = true }

                    AppIcon(title: "设置", symbol: "gearshape.fill",
                            colors: [Color(red: 0.55, green: 0.57, blue: 0.62),
                                     Color(red: 0.35, green: 0.37, blue: 0.42)],
                            size: 100) { showSettings = true }
                }

                Spacer(minLength: 0)

                NowPlayingPill(title: music.title,
                               subtitle: musicSubtitle,
                               isPlaying: music.isPlaying,
                               onTap: { showMusic = true },
                               onToggle: { music.toggle() })
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)

                DockBar {
                    DockIcon(symbol: "map.fill", tint: Color(red: 0.20, green: 0.72, blue: 0.45)) { showNav = true }
                    DockIcon(symbol: "phone.fill", tint: Color(red: 0.30, green: 0.85, blue: 0.42)) { showPhone = true }
                    DockIcon(symbol: "music.note", tint: Color(red: 0.98, green: 0.32, blue: 0.42)) { showMusic = true }
                    DockIcon(symbol: "gearshape.fill", tint: Color(red: 0.55, green: 0.57, blue: 0.62)) { showSettings = true }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 4)
            }
        }
        .statusBarHidden()
        .onAppear { location.start() }
        .task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            music.start()
        }
        .fullScreenCover(isPresented: $showNav) { NavigateView() }
        .fullScreenCover(isPresented: $showPhone) { PhoneView() }
        .fullScreenCover(isPresented: $showMusic) { NowPlayingView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var musicSubtitle: String {
        let source = MusicSource(rawValue: musicSourceRaw) ?? .apple
        if source.controllable {
            return music.artist.isEmpty ? "Apple Music" : music.artist
        }
        return source.title
    }
}

// MARK: - 背景

struct Wallpaper: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.13, blue: 0.20),
                     Color(red: 0.04, green: 0.05, blue: 0.09)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

// MARK: - 状态栏

struct CarPlayStatusBar: View {
    let speedKmh: Double
    @State private var now = Date()
    private let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 7) {
            Text(timeString)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Image(systemName: "cellularbars").font(.system(size: 13))
            Image(systemName: "wifi").font(.system(size: 13))
            Image(systemName: "battery.75").font(.system(size: 15))
            Spacer()
            if speedKmh > 1 {
                Text("\(Int(speedKmh)) km/h")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
        }
        .foregroundColor(.white.opacity(0.85))
        .onReceive(timer) { now = $0 }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }
}

// MARK: - 图标

struct AppIcon: View {
    let title: String
    let symbol: String
    let colors: [Color]
    var size: CGFloat = 96
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.44, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.92))
            }
        }
        .buttonStyle(CardButton())
    }
}

struct DockIcon: View {
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.22))
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(tint)
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(CardButton())
    }
}

struct DockBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 22) {
            Spacer()
            content
            Spacer()
        }
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
    }
}

// MARK: - 正在播放条

struct NowPlayingPill: View {
    let title: String
    let subtitle: String
    let isPlaying: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                        Image(systemName: "music.note")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(CardButton())

            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(CardButton())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
