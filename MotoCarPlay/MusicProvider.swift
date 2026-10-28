import Foundation
import MediaPlayer
import Combine
import UIKit

/// 本地音乐控制：接管 iPhone「音乐」App 资料库的播放（Apple Music 订阅歌曲 / 已下载歌曲均可）。
/// 全部调用延迟到 start()，避免启动期触发媒体库权限检查导致 TCC 闪退。
final class MusicProvider: ObservableObject {
    static let shared = MusicProvider()

    @Published var isPlaying = false
    @Published var title = "未在播放"
    @Published var artist = ""
    @Published var hasQueue = false

    private var player: MPMusicPlayerController?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        let p = MPMusicPlayerController.systemMusicPlayer
        player = p

        let center = NotificationCenter.default
        center.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange, object: p)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncPlayback() }
            .store(in: &cancellables)

        center.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange, object: p)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncItem() }
            .store(in: &cancellables)

        p.beginGeneratingPlaybackNotifications()
        syncPlayback()
        syncItem()
    }

    private func syncPlayback() {
        isPlaying = (player?.playbackState == .playing)
    }

    private func syncItem() {
        guard let player else { return }
        if let item = player.nowPlayingItem {
            title = item.title ?? "未知曲目"
            artist = item.artist ?? ""
            hasQueue = true
        } else {
            title = "未在播放"
            artist = ""
            hasQueue = player.playbackState != .stopped
        }
    }

    /// 从系统选择器拿到歌曲集合后加入队列并播放
    func play(collection: MPMediaItemCollection) {
        start()
        guard let player else { return }
        player.setQueue(with: collection)
        player.play()
    }

    func toggle() {
        start()
        guard let player else { return }
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func next() {
        start()
        player?.skipToNextItem()
    }

    func prev() {
        start()
        player?.skipToPreviousItem()
    }
}

/// MPMediaPickerController 的 SwiftUI 封装
struct MediaPicker: UIViewControllerRepresentable {
    let onPick: (MPMediaItemCollection) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = true
        picker.showsCloudItems = true
        picker.prompt = "选择要播放的歌曲（支持 Apple Music 资料库）"
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, dismiss: dismiss) }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onPick: (MPMediaItemCollection) -> Void
        let dismiss: DismissAction

        init(onPick: @escaping (MPMediaItemCollection) -> Void, dismiss: DismissAction) {
            self.onPick = onPick
            self.dismiss = dismiss
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController,
                         didPick mediaItems: [MPMediaItem]) {
            guard !mediaItems.isEmpty else { dismiss(); return }
            onPick(MPMediaItemCollection(items: mediaItems))
            dismiss()
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            dismiss()
        }
    }
}
