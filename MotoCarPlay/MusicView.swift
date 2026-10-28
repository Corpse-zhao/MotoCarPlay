import SwiftUI
import WebKit
import AVFoundation

/// 内嵌网页版播放器状态
final class WebMusicModel: ObservableObject {
    @Published var pageTitle = ""
    @Published var progress: Double = 0

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
        webView?.evaluateJavaScript(
            "(function(){var m=document.querySelector('audio,video');if(!m||!m.duration)return 0;return m.currentTime/m.duration})()"
        ) { [weak self] value, _ in
            guard let self, let ratio = value as? Double else { return }
            DispatchQueue.main.async { self.progress = min(max(ratio, 0), 1) }
        }
    }

    func reload() { webView?.reload() }
    func goBack() { if webView?.canGoBack == true { webView?.goBack() } }
    func goForward() { if webView?.canGoForward == true { webView?.goForward() } }
}

/// 音乐页：QQ音乐 / 网易云音乐 / 汽水音乐的网页版，直接在本 App 内运行
struct MusicView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("musicSource") private var sourceRaw = MusicSource.qq.rawValue
    @StateObject private var model = WebMusicModel()
    @State private var reloadToken = UUID()

    private var source: MusicSource { MusicSource(rawValue: sourceRaw) ?? .qq }

    var body: some View {
        ZStack {
            Wallpaper()

            VStack(spacing: 8) {
                topBar

                MusicWebView(url: source.url, model: model, reloadToken: reloadToken)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .statusBarHidden()
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

            Text(model.pageTitle)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)

            Spacer(minLength: 0)

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

/// WKWebView 封装：桌面 UA 换到 PC 版网页播放器
struct MusicWebView: UIViewRepresentable {
    let url: URL
    let model: WebMusicModel
    let reloadToken: UUID

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let web = WKWebView(frame: .zero, configuration: config)
        web.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
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
