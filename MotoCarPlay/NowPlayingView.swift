import SwiftUI

struct NowPlayingView: View {
    @StateObject private var music = MusicProvider.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("musicSource") private var sourceRaw = MusicSource.apple.rawValue

    private var source: MusicSource { MusicSource(rawValue: sourceRaw) ?? .apple }

    var body: some View {
        ZStack {
            Wallpaper()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(CardButton())

                    Spacer()

                    Menu {
                        ForEach(MusicSource.allCases) { item in
                            Button {
                                sourceRaw = item.rawValue
                            } label: {
                                Label(item.title, systemImage: item.symbol)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: source.symbol)
                            Text(source.title)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)

                Spacer(minLength: 0)

                if source.controllable {
                    appleMusicPane
                } else {
                    externalPane
                }

                Spacer(minLength: 0)
            }
        }
        .statusBarHidden()
        .onAppear { music.start() }
    }

    // MARK: - Apple Music（可控制）

    private var appleMusicPane: some View {
        HStack(spacing: 34) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.32, blue: 0.42),
                                                  Color(red: 0.78, green: 0.10, blue: 0.30)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "music.note")
                    .font(.system(size: 68, weight: .light))
                    .foregroundColor(.white.opacity(0.95))
            }
            .frame(width: 190, height: 190)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(music.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(music.artist.isEmpty ? "Apple Music" : music.artist)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                HStack(spacing: 34) {
                    Button { music.prev() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(CardButton())

                    Button { music.toggle() } label: {
                        Image(systemName: music.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(.white)
                            .frame(width: 76, height: 76)
                    }
                    .buttonStyle(CardButton())

                    Button { music.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(CardButton())
                }
            }
            .frame(maxWidth: 340, alignment: .leading)
        }
        .padding(.horizontal, 30)
    }

    // MARK: - 第三方播放器（仅唤起）

    private var externalPane: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                Image(systemName: source.symbol)
                    .font(.system(size: 54, weight: .light))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 140, height: 140)

            Text(source.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("受系统限制，第三方播放器无法在这里显示播放状态或控制。\n点下面按钮唤起 App，之后用耳机线控或 Siri 控制播放。")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button { source.open() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square")
                    Text("打开 \(source.title)")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 26)
                .padding(.vertical, 13)
                .background(Capsule().fill(Color(red: 0.98, green: 0.32, blue: 0.42)))
            }
            .buttonStyle(CardButton())
        }
        .padding(.horizontal, 30)
    }
}
