import Foundation
import CoreLocation
import Combine

/// 定位与车速来源：全局单例，导航页与首页共用
final class LocationProvider: NSObject, ObservableObject {
    static let shared = LocationProvider()

    let manager = CLLocationManager()

    @Published var speedKmh: Double = 0        // GPS 车速
    @Published var heading: Double = 0         // 航向角
    @Published var location: CLLocation?
    @Published var authorizationDenied = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.allowsBackgroundLocationUpdates = false
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            authorizationDenied = true
        default:
            break
        }
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func requestAlwaysIfDenied() {
        manager.requestWhenInUseAuthorization()
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationDenied = (manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc
        // GPS 速度为负值时表示无效（刚启动/室内）
        speedKmh = max(0, loc.speed * 3.6)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 忽略瞬时错误，保持上次值
    }
}
