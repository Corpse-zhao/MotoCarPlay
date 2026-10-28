import Foundation
import CoreLocation
import AMapFoundationKit
import AMapNaviKit
import AMapSearchKit

/// 高德 SDK 初始化：Key + 隐私合规（不调用隐私接口会直接崩）
/// 注意：项目只链 AMapNaviKit（11.x 内置完整地图引擎，与 AMap3DMap 互斥），
/// MAMapView 等地图类型由 AMapNaviKit 头文件透出。
enum AMapConfig {
    static let apiKey = "5d823b966a591be1f6d855c15767848d"

    static func setup() {
        AMapServices.shared().apiKey = apiKey
        AMapServices.shared().enableHTTPS = true

        // 导航 SDK 隐私合规（必须最先调用）
        let naviConfig = AMapNaviManagerConfig.sharedConfig()
        naviConfig.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        naviConfig.updatePrivacyAgree(.didAgree)

        // 地图 / 搜索 SDK 隐私合规
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
        AMapSearchAPI.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapSearchAPI.updatePrivacyAgree(.didAgree)
    }
}

/// 搜索结果（高德 POI，坐标已是 GCJ-02）
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

/// WGS84 → GCJ-02 转换。
/// CLLocationManager 给的是 WGS84，直接传给高德接口会整体偏移几百米。
enum CoordTransform {
    private static let a = 6378245.0
    private static let ee = 0.00669342162296594323

    static func wgs84ToGcj02(_ coord: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 粗判是否在中国大陆范围外（境外不偏移）
        if coord.longitude < 72.004 || coord.longitude > 137.8347 ||
           coord.latitude < 0.8293 || coord.latitude > 55.8271 {
            return coord
        }
        var dLat = transformLat(coord.longitude - 105.0, coord.latitude - 35.0)
        var dLon = transformLon(coord.longitude - 105.0, coord.latitude - 35.0)
        let radLat = coord.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return CLLocationCoordinate2D(latitude: coord.latitude + dLat,
                                      longitude: coord.longitude + dLon)
    }

    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }
}
