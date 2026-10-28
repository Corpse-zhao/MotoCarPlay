import SwiftUI

/// 音乐源。
/// QQ音乐 / 网易云音乐：内嵌网页版（桌面 UA，等于 PC 版播放器）。
/// 汽水音乐：官网只有 H5 下载页，没有网页播放器，所以内嵌页面 + 提供「用汽水 App 播」的兜底。
/// 本地音乐：系统资料库，原生可控。
enum MusicSource: String, CaseIterable, Identifiable {
    case qishui
    case qq
    case netease
    case local

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qishui: return "汽水音乐"
        case .qq: return "QQ音乐"
        case .netease: return "网易云音乐"
        case .local: return "本地音乐"
        }
    }

    var url: URL? {
        switch self {
        case .qishui: return URL(string: "https://qishui.douyin.com/")
        case .qq: return URL(string: "https://y.qq.com/")
        case .netease: return URL(string: "https://music.163.com/")
        case .local: return nil
        }
    }

    /// 用桌面 UA 才能拿到 PC 版播放器
    var usesDesktopUA: Bool {
        switch self {
        case .qq, .netease: return true
        default: return false
        }
    }

    /// 外部 App 深链（仅汽水作为兜底）
    var deepLink: String? {
        switch self {
        case .qishui: return "qishui://"
        default: return nil
        }
    }

    var symbol: String {
        switch self {
        case .qishui: return "drop.fill"
        case .qq: return "music.quarternote.3"
        case .netease: return "waveform"
        case .local: return "square.and.arrow.down.on.square"
        }
    }

    var color: Color {
        switch self {
        case .qishui: return Color(red: 0.35, green: 0.85, blue: 0.90)
        case .qq: return Color(red: 0.20, green: 0.78, blue: 0.42)
        case .netease: return Color(red: 0.92, green: 0.20, blue: 0.24)
        case .local: return Color(red: 0.98, green: 0.32, blue: 0.42)
        }
    }

    func openExternal() {
        guard let link = deepLink, let url = URL(string: link),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
