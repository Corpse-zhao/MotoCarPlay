import SwiftUI

struct NowPlayingView: View {
    @StateObject private var music = MusicProvider.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 28) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 48, height: 48)
                    }
                    Spacer()
                    Text("正在播放")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Color.clear.frame(width: 48, height: 48)
                }
                .padding(.horizontal, 16)

                Spacer()

                // 封面占位（大圆盘，二期可换真封面）
                ZStack {
                    Circle()
                        .fill(Theme.card)
                        .frame(width: 230, height: 230)
                    Image(systemName: "music.note")
                        .font(.system(size: 70, weight: .light))
                        .foregroundColor(Theme.accent)
                }

                VStack(spacing: 6) {
                    Text(music.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(music.artist)
                        .font(.system(size: 17))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 24)

                Spacer()

                // 大按钮控制条
                HStack(spacing: 46) {
                    Button { music.prev() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Button { music.toggle() } label: {
                        Image(systemName: music.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 82, weight: .light))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Button { music.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                .buttonStyle(CardButton())
                .padding(.bottom, 44)
            }
        }
        .onAppear { music.start() }
    }
}
