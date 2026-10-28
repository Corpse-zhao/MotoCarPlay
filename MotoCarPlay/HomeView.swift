import SwiftUI

/// 多功能页：CarPlay 风格图标网格（左滑返回地图主界面）
struct AppsPageView: View {
    let onMap: () -> Void
    let onNavigate: () -> Void
    let onPhone: () -> Void
    let onMusic: () -> Void
    let onSettings: () -> Void
    let onSwipeBack: () -> Void

    @StateObject private var location = LocationProvider.shared

    var body: some View {
        ZStack {
            Wallpaper()

            VStack(spacing: 0) {
                AppsStatusBar(speedKmh: location.speedKmh)
                    .padding(.horizontal, 28)
                    .padding(.top, 6)

                Spacer(minLength: 0)

                HStack(spacing: 30) {
                    AppIcon(title: "地图", symbol: "map.fill",
                            colors: [Color(red: 0.20, green: 0.62, blue: 0.98),
                                     Color(red: 0.08, green: 0.38, blue: 0.78)],
                            size: 88, action: onMap)

                    AppIcon(title: "导航", symbol: "arrow.triangle.turn.up.right.circle.fill",
                            colors: [Color(red: 0.20, green: 0.72, blue: 0.45),
                                     Color(red: 0.10, green: 0.48, blue: 0.30)],
                            size: 88, action: onNavigate)

                    AppIcon(title: "电话", symbol: "phone.fill",
                            colors: [Color(red: 0.30, green: 0.85, blue: 0.42),
                                     Color(red: 0.10, green: 0.60, blue: 0.28)],
                            size: 88, action: onPhone)

                    AppIcon(title: "音乐", symbol: "music.note",
                            colors: [Color(red: 0.98, green: 0.32, blue: 0.42),
                                     Color(red: 0.80, green: 0.12, blue: 0.32)],
                            size: 88, action: onMusic)

                    AppIcon(title: "设置", symbol: "gearshape.fill",
                            colors: [Color(red: 0.55, green: 0.57, blue: 0.62),
                                     Color(red: 0.35, green: 0.37, blue: 0.42)],
                            size: 88, action: onSettings)
                }

                Spacer(minLength: 0)

                Text("左滑返回地图")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 10)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -60 { onSwipeBack() }
                }
        )
        .statusBarHidden()
    }
}

// MARK: - 状态栏

struct AppsStatusBar: View {
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

// MARK: - 通用组件

struct Wallpaper: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.13, blue: 0.20),
                     Color(red: 0.04, green: 0.05, blue: 0.09)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

struct AppIcon: View {
    let title: String
    let symbol: String
    let colors: [Color]
    var size: CGFloat = 88
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.42, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.92))
            }
        }
        .buttonStyle(CardButton())
    }
}
