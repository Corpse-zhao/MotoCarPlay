import Foundation
import CoreLocation
import Combine
import AMapSearchKit

/// 高德 POI 搜索（导航交给 AMapNaviController）
final class NavigationModel: NSObject, ObservableObject {
    @Published var pois: [POIResult] = []
    @Published var searchFailed = false

    private let search: AMapSearchAPI? = AMapSearchAPI()

    override init() {
        super.init()
        search?.delegate = self
    }

    func searchPOI(_ keyword: String, near location: CLLocation?) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchFailed = false

        let request = AMapPOIKeywordsSearchRequest()
        request.keywords = trimmed
        request.cityLimit = false
        request.offset = 20
        request.page = 1
        if let loc = location {
            // 检索坐标也要 GCJ-02
            let gcj = CoordTransform.wgs84ToGcj02(loc.coordinate)
            request.location = AMapGeoPoint.from(gcj)
            request.sortrule = 1  // 按距离排序
        }
        search?.aMapPOIKeywordsSearch(request)
    }
}

extension NavigationModel: AMapSearchDelegate {
    func onPOISearchDone(_ request: AMapPOISearchBaseRequest!, response: AMapPOISearchResponse!) {
        guard let response, request is AMapPOIKeywordsSearchRequest else { return }
        let list = response.pois ?? []
        DispatchQueue.main.async {
            // SDK 的 poi.distance 常为 0，自己算：当前定位（GCJ）到 POI 的直线距离
            let userGCJ = LocationProvider.shared.location.map { CoordTransform.wgs84ToGcj02($0.coordinate) }
            let userLoc = userGCJ.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
            self.pois = list.map { poi in
                let coord = poi.location.clCoordinate
                var dist = Double(poi.distance)
                if dist <= 0, let userLoc {
                    dist = userLoc.distance(from: CLLocation(latitude: coord.latitude,
                                                             longitude: coord.longitude))
                }
                return POIResult(name: poi.name ?? "未知地点",
                                 address: poi.address ?? "",
                                 coordinate: coord,
                                 distance: dist)
            }
            self.searchFailed = list.isEmpty
        }
    }

    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        DispatchQueue.main.async {
            self.searchFailed = true
        }
    }
}

extension AMapGeoPoint {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: CLLocationDegrees(latitude),
                               longitude: CLLocationDegrees(longitude))
    }

    static func from(_ coordinate: CLLocationCoordinate2D) -> AMapGeoPoint {
        AMapGeoPoint.location(withLatitude: CGFloat(coordinate.latitude),
                              longitude: CGFloat(coordinate.longitude))
    }
}
