import Foundation
import CoreLocation
import Combine
import AMapSearchKit

/// 高德 POI 搜索 → 驾车路径规划 → 实时转向指引 + 偏航重算
final class NavigationModel: NSObject, ObservableObject {
    @Published var pois: [POIResult] = []
    @Published var route: RouteData?
    @Published var destination: RouteDestination?

    @Published var currentSymbol = "arrow.up"
    @Published var currentInstruction = ""
    @Published var nextInstruction = ""
    @Published var distanceToManeuver: CLLocationDistance = 0
    @Published var remainingDistance: CLLocationDistance = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var isRerouting = false
    @Published var searchFailed = false

    private let search: AMapSearchAPI? = AMapSearchAPI()
    private var cancellables = Set<AnyCancellable>()
    private var lastStepIndex = 0
    private var lastRerouteAt = Date.distantPast
    private var hasGuidance = false

    override init() {
        super.init()
        search?.delegate = self
        LocationProvider.shared.$location
            .sink { [weak self] loc in self?.onLocation(loc) }
            .store(in: &cancellables)
    }

    // MARK: - 搜索

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
            request.location = AMapGeoPoint.from(loc.coordinate)
            request.sortrule = 1  // 按距离排序
        }
        search?.aMapPOIKeywordsSearch(request)
    }

    // MARK: - 路线

    func setDestination(_ poi: POIResult) {
        finishDestination(RouteDestination(name: poi.name, coordinate: poi.coordinate))
    }

    func setDestination(name: String, coordinate: CLLocationCoordinate2D) {
        finishDestination(RouteDestination(name: name, coordinate: coordinate))
    }

    private func finishDestination(_ dest: RouteDestination) {
        destination = dest
        pois = []
        hasGuidance = false
        guard let loc = LocationProvider.shared.location else {
            currentSymbol = "exclamationmark.triangle"
            currentInstruction = "还没拿到定位，稍后再试"
            return
        }
        requestRoute(from: loc.coordinate, to: dest.coordinate)
    }

    private func requestRoute(from origin: CLLocationCoordinate2D,
                              to destination: CLLocationCoordinate2D) {
        let request = AMapDrivingRouteSearchRequest()
        request.origin = AMapGeoPoint.from(origin)
        request.destination = AMapGeoPoint.from(destination)
        request.strategy = 0        // 速度优先
        request.requireExtension = true
        search?.aMapDrivingRouteSearch(request)
    }

    func cancel() {
        route = nil
        destination = nil
        hasGuidance = false
        currentInstruction = ""
        nextInstruction = ""
        currentSymbol = "arrow.up"
        distanceToManeuver = 0
        remainingDistance = 0
        remainingTime = 0
    }

    // MARK: - 指引

    private func initializeGuidance() {
        guard let route = route else { return }
        remainingDistance = route.distance
        remainingTime = route.duration
        lastStepIndex = 0
        hasGuidance = true

        if let first = route.steps.first(where: { !$0.instruction.isEmpty }) {
            currentSymbol = Self.symbol(for: first.instruction)
            currentInstruction = first.instruction
            distanceToManeuver = first.distance
        } else {
            currentSymbol = "arrow.up"
            currentInstruction = "沿路线出发"
            distanceToManeuver = route.distance
        }
        if let loc = LocationProvider.shared.location {
            updateGuidance(with: loc)
        }
    }

    private func onLocation(_ loc: CLLocation?) {
        guard let loc, let route = route else { return }

        if hasGuidance, let dest = destination,
           distance(from: loc.coordinate, to: route.coordinates) > 80,
           Date().timeIntervalSince(lastRerouteAt) > 10 {
            lastRerouteAt = Date()
            isRerouting = true
            requestRoute(from: loc.coordinate, to: dest.coordinate)
            return
        }
        updateGuidance(with: loc)
    }

    private func updateGuidance(with loc: CLLocation) {
        guard let route = route, !route.steps.isEmpty else { return }

        var bestIndex = min(lastStepIndex, route.steps.count - 1)
        var bestDist = Double.greatestFiniteMagnitude
        for (i, step) in route.steps.enumerated() where !step.coordinates.isEmpty {
            let d = distance(from: loc.coordinate, to: step.coordinates)
            if d < bestDist {
                bestDist = d
                bestIndex = i
            }
        }
        lastStepIndex = bestIndex

        let step = route.steps[bestIndex]
        currentInstruction = step.instruction.isEmpty ? "沿当前道路行驶" : step.instruction
        currentSymbol = Self.symbol(for: currentInstruction)
        distanceToManeuver = max(0, distanceAlong(step.coordinates, from: loc.coordinate))

        if let next = route.steps[(bestIndex + 1)...].first(where: { !$0.instruction.isEmpty }) {
            nextInstruction = next.instruction
        } else {
            nextInstruction = ""
        }

        var remain = max(0, step.distance - distanceToManeuver)
        for s in route.steps[(bestIndex + 1)...] {
            remain += s.distance
        }
        remainingDistance = remain
        if route.distance > 0 {
            remainingTime = route.duration * (remain / route.distance)
        }
    }

    static func symbol(for instruction: String) -> String {
        if instruction.contains("掉头") { return "arrow.uturn.left" }
        if instruction.contains("左转") { return "arrow.turn.up.left" }
        if instruction.contains("右转") { return "arrow.turn.up.right" }
        if instruction.contains("向左") || instruction.contains("靠左") { return "arrow.up.left" }
        if instruction.contains("向右") || instruction.contains("靠右") { return "arrow.up.right" }
        if instruction.contains("环岛") { return "arrow.triangle.2.circlepath.circle" }
        if instruction.contains("出口") || instruction.contains("驶出") { return "arrow.down.right" }
        return "arrow.up"
    }

    // MARK: - 几何

    private func distance(from point: CLLocationCoordinate2D,
                          to line: [CLLocationCoordinate2D]) -> CLLocationDistance {
        measure(point, line, measureWhole: true)
    }

    private func distanceAlong(_ line: [CLLocationCoordinate2D],
                               from point: CLLocationCoordinate2D) -> CLLocationDistance {
        measure(point, line, measureWhole: false)
    }

    private func measure(_ point: CLLocationCoordinate2D,
                         _ line: [CLLocationCoordinate2D],
                         measureWhole: Bool) -> CLLocationDistance {
        guard line.count > 1 else { return 0 }
        var best = Double.greatestFiniteMagnitude
        var bestAlong: CLLocationDistance = 0
        var along: CLLocationDistance = 0

        for i in 0..<(line.count - 1) {
            let a = CLLocation(latitude: line[i].latitude, longitude: line[i].longitude)
            let b = CLLocation(latitude: line[i + 1].latitude, longitude: line[i + 1].longitude)
            let segLen = a.distance(from: b)
            let (projDist, projAlong) = project(point: point, from: a, to: b)
            if projDist < best {
                best = projDist
                bestAlong = along + projAlong
            }
            along += segLen
        }
        return measureWhole ? best : bestAlong
    }

    private func project(point: CLLocationCoordinate2D,
                         from a: CLLocation, to b: CLLocation) -> (CLLocationDistance, CLLocationDistance) {
        let segLen = max(a.distance(from: b), 0.0001)
        let bearingAB = a.coordinate.bearing(to: b.coordinate)
        let bearingAP = a.coordinate.bearing(to: point)
        let p = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let ap = a.distance(from: p)
        let angleDiff = (bearingAP - bearingAB) * .pi / 180
        let t = max(0, min(segLen, ap * cos(angleDiff)))
        let projCoord = a.coordinate.coordinate(at: t, bearing: bearingAB)
        let proj = CLLocation(latitude: projCoord.latitude, longitude: projCoord.longitude)
        return (p.distance(from: proj), t)
    }
}

// MARK: - 高德搜索回调

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

    func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
        DispatchQueue.main.async {
            self.isRerouting = false
            guard let path = response?.route?.paths?.first else {
                if self.route == nil {
                    self.currentSymbol = "exclamationmark.triangle"
                    self.currentInstruction = "路径规划失败，换个目的地试试"
                }
                return
            }

            let steps: [RouteStep] = (path.steps ?? []).map { step in
                RouteStep(instruction: step.instruction ?? "",
                          distance: CLLocationDistance(step.distance),
                          coordinates: (step.polyline ?? "").amapCoordinates)
            }

            var all: [CLLocationCoordinate2D] = []
            for s in steps { all.append(contentsOf: s.coordinates) }
            if all.isEmpty {
                all = (path.polyline ?? "").amapCoordinates
            }

            self.route = RouteData(distance: CLLocationDistance(path.distance),
                                   duration: TimeInterval(path.duration),
                                   coordinates: all,
                                   steps: steps)
            self.initializeGuidance()
        }
    }

    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        DispatchQueue.main.async {
            self.isRerouting = false
            if self.route == nil {
                self.currentSymbol = "exclamationmark.triangle"
                self.currentInstruction = "高德接口返回错误：\(error?.localizedDescription ?? "未知")"
            }
        }
    }
}

extension CLLocationCoordinate2D {
    func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude * .pi / 180, lat2 = other.latitude * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    func coordinate(at distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        let r = 6371000.0
        let brng = bearing * .pi / 180
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(distance / r) + cos(lat1) * sin(distance / r) * cos(brng))
        let lon2 = lon1 + atan2(sin(brng) * sin(distance / r) * cos(lat1),
                                cos(distance / r) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}
