import Foundation
import CoreLocation
import AMapFoundationKit
import MAMapKit
import AMapSearchKit

/// 高德 SDK 初始化：Key + 隐私合规（不调用隐私接口会直接崩）
enum AMapConfig {
    static let apiKey = "5d823b966a591be1f6d855c15767848d"

    static func setup() {
        AMapServices.shared().apiKey = apiKey
        AMapServices.shared().enableHTTPS = true

        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)

        AMapSearchAPI.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapSearchAPI.updatePrivacyAgree(.didAgree)
    }
}

/// 搜索结果（高德 POI）
struct POIResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let distance: Double
}

/// 导航目的地
struct RouteDestination {
    let name: String
    let coordinate: CLLocationCoordinate2D
}

/// 路径中的一段（高德 step）
struct RouteStep {
    let instruction: String
    let distance: CLLocationDistance
    let coordinates: [CLLocationCoordinate2D]
}

/// 完整路径
struct RouteData {
    let distance: CLLocationDistance
    let duration: TimeInterval
    let coordinates: [CLLocationCoordinate2D]
    let steps: [RouteStep]
}

extension String {
    /// 高德 polyline 字符串 "lon,lat;lon,lat" → 坐标数组
    var amapCoordinates: [CLLocationCoordinate2D] {
        split(separator: ";").compactMap { pair in
            let parts = pair.split(separator: ",")
            guard parts.count >= 2,
                  let lon = Double(parts[0]),
                  let lat = Double(parts[1]) else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}

extension AMapGeoPoint {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: CLLocationDegrees(latitude), longitude: CLLocationDegrees(longitude))
    }

    static func from(_ coordinate: CLLocationCoordinate2D) -> AMapGeoPoint {
        AMapGeoPoint.location(withLatitude: CGFloat(coordinate.latitude),
                              longitude: CGFloat(coordinate.longitude))
    }
}
