import Foundation
import MediaPlayer
import Combine

/// 系统音乐控制：接管 Apple Music / 本地曲库的当前播放
final class MusicProvider: ObservableObject {
    static let shared = MusicProvider()

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var cancellables = Set<AnyCancellable>()

    @Published var isPlaying = false
    @Published var title = "未在播放"
    @Published var artist = ""
    @Published var elapsed: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private override init() {
        super.init()

        let center = NotificationCenter.default
        center.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
            .sink { [weak self] _ in self?.syncPlayback() }
            .store(in: &cancellables)

        center.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
            .sink { [weak self] _ in self?.syncItem() }
            .store(in: &cancellables)

        center.publisher(for: .MPMusicPlayerControllerQueueDidChange, object: player)
            .sink { [weak self] _ in self?.syncItem() }
            .store(in: &cancellables)

        player.beginGeneratingPlaybackNotifications()
        syncPlayback()
        syncItem()
    }

    private func syncPlayback() {
        isPlaying = (player.playbackState == .playing)
    }

    private func syncItem() {
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
        player.playbackState == .playing ? player.pause() : player.play()
    }

    func next() { player.skipToNextItem() }
    func prev() { player.skipToPreviousItem() }

    /// 骑行建议：出发前在 Apple Music 里点开歌单，这里就能接管
    var usable: Bool {
        player.playbackState != .stopped || player.nowPlayingItem != nil
    }
}
