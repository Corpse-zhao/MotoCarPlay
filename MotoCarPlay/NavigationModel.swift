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
            self.pois = list.map {
                POIResult(name: $0.name ?? "未知地点",
                          address: $0.address ?? "",
                          coordinate: $0.location.clCoordinate,
                          distance: Double($0.distance))
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
