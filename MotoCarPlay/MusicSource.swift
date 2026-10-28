import SwiftUI

/// 音乐源：全部以「内嵌网页版（PC 版）」方式在本 App 内运行，不跳转外部 App
enum MusicSource: String, CaseIterable, Identifiable {
    case qq
    case netease
    case qishui

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qq: return "QQ音乐"
        case .netease: return "网易云音乐"
        case .qishui: return "汽水音乐"
        }
    }

    var url: URL {
        switch self {
        case .qq: return URL(string: "https://y.qq.com/")!
        case .netease: return URL(string: "https://music.163.com/")!
        case .qishui: return URL(string: "https://qishui.douyin.com/")!
        }
    }

    var symbol: String {
        switch self {
        case .qq: return "music.quarternote.3"
        case .netease: return "waveform"
        case .qishui: return "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .qq: return Color(red: 0.20, green: 0.78, blue: 0.42)
        case .netease: return Color(red: 0.92, green: 0.20, blue: 0.24)
        case .qishui: return Color(red: 0.35, green: 0.85, blue: 0.90)
        }
    }
}
