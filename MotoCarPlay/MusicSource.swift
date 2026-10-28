import Foundation
import UIKit

/// 可选音乐播放器。
/// 只有 Apple Music 能被第三方 App 通过公共 API 直接控制（MPMusicPlayerController），
/// 其他播放器受系统沙盒限制，只能负责"唤起"，播放/切换请用耳机线控或 Siri。
enum MusicSource: String, CaseIterable, Identifiable {
    case apple
    case netease
    case qq
    case spotify
    case kugou

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return "Apple Music"
        case .netease: return "网易云音乐"
        case .qq: return "QQ音乐"
        case .spotify: return "Spotify"
        case .kugou: return "酷狗音乐"
        }
    }

    var symbol: String {
        switch self {
        case .apple: return "music.note"
        case .netease: return "waveform"
        case .qq: return "music.quarternote.3"
        case .spotify: return "dot.radiowaves.left.and.right"
        case .kugou: return "music.mic"
        }
    }

    var scheme: String? {
        switch self {
        case .apple: return "music://"
        case .netease: return "orpheus://"
        case .qq: return "qqmusic://"
        case .spotify: return "spotify://"
        case .kugou: return "kugou://"
        }
    }

    /// 能否在车机界面里直接显示/控制播放
    var controllable: Bool { self == .apple }

    func open() {
        guard let scheme = scheme, let url = URL(string: scheme) else { return }
        UIApplication.shared.open(url, options: [:]) { ok in
            if !ok, let store = URL(string: "https://apps.apple.com/cn/search?term=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                UIApplication.shared.open(store)
            }
        }
    }
}
