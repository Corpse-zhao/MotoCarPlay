import SwiftUI
import WebKit
import AVFoundation
import MediaPlayer

/// 内嵌网页版播放器状态
final class WebMusicModel: ObservableObject {
    @Published var pageTitle = ""

    weak var webView: WKWebView?
    private var timer: Timer?

    func attach(_ web: WKWebView) {
        webView = web
        activateAudioSession()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    private func poll() {
        webView?.evaluateJavaScript("document.title") { [weak self] value, _ in
            guard let self, let text = value as? String, !text.isEmpty else { return }
            DispatchQueue.main.async { self.pageTitle = text }
        }
    }

    func reload() { webView?.reload() }
    func goBack() { if webView?.canGoBack == true { webView?.goBack() } }
}

/// 音乐页：QQ音乐 / 网易云音乐 = 内嵌网页版；本地音乐 = 系统资料库原生控制
struct MusicView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("musicSource") private var sourceRaw = MusicSource.qq.rawValue
    @StateObject private var model = WebMusicModel()
    @StateObject private var music = MusicProvider.shared
    @State private var reloadToken = UUID()
    @State private var showPicker = false

    private var source: MusicSource { MusicSource(rawValue: sourceRaw) ?? .qq }

    var body: some View {
        ZStack {
            Wallpaper()

            VStack(spacing: 8) {
                topBar

                if source == .local {
                    localPane
                } else if let url = source.url {
                    ZStack(alignment: .bottomTrailing) {
                        MusicWebView(url: url, model: model, reloadToken: reloadToken,
                                     desktopUA: source.usesDesktopUA)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )

                        if source.deepLink != nil {
                            Button {
                                FloatingLauncher.openQishui { _ in }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("浮窗打开汽水")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Color.black.opacity(0.7)))
                            }
                            .buttonStyle(CardButton())
                            .padding(12)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .statusBarHidden()
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            music.start()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(CardButton())

            Menu {
                ForEach(MusicSource.allCases) { item in
                    Button {
                        sourceRaw = item.rawValue
                        reloadToken = UUID()
                    } label: {
                        Label(item.title, systemImage: item.symbol)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: source.symbol)
                    Text(source.title)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(source.color.opacity(0.35)))
            }

            if source != .local {
                Text(model.pageTitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if source != .local {
                Button { model.goBack() } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 34, height: 30)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(CardButton())

                Button {
                    model.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 34, height: 30)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(CardButton())
            }
        }
    }

    // MARK: - 本地音乐（原生控制）

    private var localPane: some View {
        HStack(spacing: 34) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.32, blue: 0.42),
                                                  Color(red: 0.78, green: 0.10, blue: 0.30)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "music.note")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.white.opacity(0.95))
            }
            .frame(width: 170, height: 170)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(music.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(music.artist.isEmpty ? "iPhone 音乐资料库" : music.artist)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                HStack(spacing: 28) {
                    Button { music.prev() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(CardButton())

                    Button { music.toggle() } label: {
                        Image(systemName: music.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 58, weight: .light))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                    }
                    .buttonStyle(CardButton())

                    Button { music.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(CardButton())
                }

                Button {
                    showPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.plus")
                        Text("从资料库选歌")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color(red: 0.98, green: 0.32, blue: 0.42)))
                }
                .buttonStyle(CardButton())
            }
            .frame(maxWidth: 360, alignment: .leading)
        }
        .padding(.horizontal, 30)
        .sheet(isPresented: $showPicker) {
            MediaPicker { collection in
                music.play(collection: collection)
            }
            .preferredColorScheme(.dark)
        }
    }
}

/// WKWebView 封装：桌面 UA 换到 PC 版网页播放器
struct MusicWebView: UIViewRepresentable {
    let url: URL
    let model: WebMusicModel
    let reloadToken: UUID
    var desktopUA: Bool = true

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let web = WKWebView(frame: .zero, configuration: config)
        if desktopUA {
            web.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        } else {
            web.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        }
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.showsVerticalScrollIndicator = false
        web.backgroundColor = .black
        web.isOpaque = false
        model.attach(web)
        context.coordinator.loadedToken = reloadToken
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        if context.coordinator.loadedToken != reloadToken {
            context.coordinator.loadedToken = reloadToken
            web.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let model: WebMusicModel
        var loadedToken: UUID?

        init(model: WebMusicModel) { self.model = model }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let title = webView.title, !title.isEmpty {
                DispatchQueue.main.async { self.model.pageTitle = title }
            }
        }
    }
}
