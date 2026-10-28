import Foundation
import MediaPlayer
import Combine

/// 系统音乐控制：接管 Apple Music / 本地曲库的当前播放。
/// 注意：不能在 init 里访问媒体库，否则缺少 TCC 用途说明时进程会被直接终止。
/// 所以播放器全部延迟到 start() 之后才碰，UI 层负责在界面出现后调用。
final class MusicProvider: ObservableObject {
    static let shared = MusicProvider()

    @Published var isPlaying = false
    @Published var title = "未在播放"
    @Published var artist = ""
    @Published var elapsed: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: MPMusicPlayerController?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    private init() {}

    /// 界面出现后再调用，避免启动期触发媒体库权限检查
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

        center.publisher(for: .MPMusicPlayerControllerQueueDidChange, object: p)
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
            duration = item.playbackDuration
        } else {
            title = "未在播放"
            artist = ""
            duration = 0
        }
        elapsed = player.currentPlaybackTime
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
