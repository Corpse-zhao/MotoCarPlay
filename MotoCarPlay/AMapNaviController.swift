import Foundation
import AMapNaviKit
import AVFoundation
import CoreLocation
import Combine

/// 高德原生导航（AMapNaviKit 11.2.100 真实 API）：
/// AMapNaviDriveManager.sharedInstance() + addDataRepresentative(AMapNaviDriveView)
/// 自带车头向上、放大道路、路口大图、车道指引，由 SDK 全权渲染
final class AMapNaviController: NSObject, ObservableObject {
    static let shared = AMapNaviController()

    @Published var isNavigating = false
    @Published var calculating = false
    @Published var statusText: String?

    private var driveManager: AMapNaviDriveManager?
    private var driveView: AMapNaviDriveView?
    private var cruiseView: AMapNaviDriveView?
    private var routeReady = false

    /// 语音播报：SDK 只回调文字，播报由本类用系统 TTS 合成
    private let synthesizer = AVSpeechSynthesizer()
    private var feedbackCancellables = Set<AnyCancellable>()

    private func setupIfNeeded() {
        guard driveManager == nil else { return }
        let manager = AMapNaviDriveManager.sharedInstance()
        manager.delegate = self
        driveManager = manager

        // 把 App 自己的定位 + 罗盘喂给导航 SDK：
        // 静止时 SDK 拿不到 GPS course，箭头不会转；喂入磁力计方向后箭头跟随手机指向
        let lp = LocationProvider.shared
        lp.$location.sink { [weak self] _ in self?.feedExternalLocation() }
            .store(in: &feedbackCancellables)
        lp.$heading.sink { [weak self] _ in self?.feedExternalLocation() }
            .store(in: &feedbackCancellables)
    }

    /// 当前车头方向：移动中用 GPS course，静止时用磁力计（屏幕前方 = 手机顶部 + 横屏偏移）
    private var naviCourse: CLLocationDirection {
        let lp = LocationProvider.shared
        if let loc = lp.location, loc.speed > 1.0, loc.course >= 0 {
            return loc.course
        }
        let screenForward = lp.heading + Compass.screenUpOffset()
        return screenForward.truncatingRemainder(dividingBy: 360)
    }

    private func feedExternalLocation() {
        guard isNavigating, let loc = LocationProvider.shared.location else { return }
        let gcj = CoordTransform.wgs84ToGcj02(loc.coordinate)
        let external = CLLocation(coordinate: gcj,
                                  altitude: loc.altitude,
                                  horizontalAccuracy: loc.horizontalAccuracy,
                                  verticalAccuracy: loc.verticalAccuracy,
                                  course: naviCourse,
                                  speed: max(0, loc.speed),
                                  timestamp: Date())
        driveManager?.setExternalLocation(external, isAMapCoordinate: true)
    }

    /// 选定目的地后调用：切到导航界面并开始算路
    func beginNavigation(to dest: RouteDestination) {
        guard let loc = LocationProvider.shared.location else {
            statusText = "还没拿到定位，等几秒再试"
            return
        }
        setupIfNeeded()
        statusText = nil
        calculating = true
        isNavigating = true
        routeReady = false

        // 起点：WGS84 → GCJ-02，否则起点会偏几百米
        let originGCJ = CoordTransform.wgs84ToGcj02(loc.coordinate)
        guard let origin = AMapNaviPoint.location(withLatitude: CGFloat(originGCJ.latitude),
                                                  longitude: CGFloat(originGCJ.longitude)),
              let end = AMapNaviPoint.location(withLatitude: CGFloat(dest.coordinate.latitude),
                                               longitude: CGFloat(dest.coordinate.longitude)) else {
            statusText = "坐标构造失败"
            return
        }

        // 开导航前必须先关巡航（SDK 要求）
        driveManager?.detectedMode = AMapNaviDetectedMode(rawValue: 0)!   // none
        driveManager?.stopNavi()
        driveManager?.calculateDriveRoute(withStart: [origin],
                                          end: [end],
                                          wayPoints: [],
                                          drivingStrategy: .drivingStrategySingleDefault)
    }

    /// 待机地图页：巡航模式（车头向上 + 电子眼播报提醒）
    func attachCruise(view: AMapNaviDriveView) {
        cruiseView = view
        setupIfNeeded()
        driveManager?.addDataRepresentative(view)
        driveManager?.detectedMode = AMapNaviDetectedMode(rawValue: 1)!   // camera：电子眼
    }

    func detachCruise(view: AMapNaviDriveView) {
        driveManager?.removeDataRepresentative(view)
        if cruiseView === view { cruiseView = nil }
    }

    /// 导航界面创建后挂进来；如果路线已算好就立刻开播
    func attach(view: AMapNaviDriveView) {
        driveView = view
        setupIfNeeded()
        driveManager?.addDataRepresentative(view)
        tryStart()
    }

    func detach(view: AMapNaviDriveView) {
        driveManager?.removeDataRepresentative(view)
        if driveView === view { driveView = nil }
    }

    func stop() {
        driveManager?.stopNavi()
        synthesizer.stopSpeaking(at: .immediate)
        isNavigating = false
        calculating = false
        statusText = nil
    }

    /// 系统TTS播报导航语音（激活音频会话，压低音乐音量）
    private func speak(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.52
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    private func tryStart() {
        // 条件：路线已算好 + 导航视图已挂载
        guard routeReady, driveView != nil else { return }
        calculating = false
        driveManager?.startGPSNavi()
    }
}

// MARK: - 高德导航回调

extension AMapNaviController: AMapNaviDriveManagerDelegate {
    func driveManager(_ driveManager: AMapNaviDriveManager, onCalculateRouteSuccessWith type: AMapNaviRoutePlanType) {
        DispatchQueue.main.async {
            self.routeReady = true
            self.statusText = nil
            self.tryStart()
        }
    }

    func driveManager(_ driveManager: AMapNaviDriveManager, onCalculateRouteFailure error: Error) {
        DispatchQueue.main.async {
            self.calculating = false
            self.isNavigating = false
            self.statusText = "路线规划失败：\(error.localizedDescription)"
        }
    }

    func driveManager(_ driveManager: AMapNaviDriveManager, error error: Error) {
        DispatchQueue.main.async {
            self.statusText = "导航出错：\(error.localizedDescription)"
        }
    }

    func driveManager(_ driveManager: AMapNaviDriveManager, onArrivedDestination NaviArrivedDestination: Int) {
        DispatchQueue.main.async {
            self.stop()
        }
    }

    /// 导航语音播报文字回调（路况、转向、电子眼等），用系统 TTS 念出来
    func driveManager(_ driveManager: AMapNaviDriveManager, playNaviSound soundString: String, soundStringType soundStringType: AMapNaviSoundType) {
        let text = soundString
        DispatchQueue.main.async {
            self.speak(text)
        }
    }
}
