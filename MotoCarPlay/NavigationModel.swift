import Foundation
import MapKit
import Combine

/// 搜索目的地 → 规划路线 → 跟车定位算出"下一个转向"和剩余距离
final class NavigationModel: NSObject, ObservableObject {
    @Published var searchResults: [MKMapItem] = []
    @Published var route: MKRoute?
    @Published var destination: MKMapItem?

    @Published var currentInstruction = ""
    @Published var distanceToManeuver: CLLocationDistance = 0
    @Published var remainingDistance: CLLocationDistance = 0
    @Published var remainingTime: TimeInterval = 0

    private var cancellables = Set<AnyCancellable>()
    private var lastStepIndex = 0

    override init() {
        super.init()
        LocationProvider.shared.$location
            .sink { [weak self] loc in self?.onLocation(loc) }
            .store(in: &cancellables)
    }

    // MARK: - 搜索与路线

    func search(_ query: String, near location: CLLocation?) {
        guard !query.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let loc = location {
            request.region = MKCoordinateRegion(
                center: loc.coordinate,
                latitudinalMeters: 30000, longitudinalMeters: 30000)
        }
        MKLocalSearch(request: request).start { [weak self] resp, _ in
            DispatchQueue.main.async {
                self?.searchResults = resp?.mapItems ?? []
            }
        }
    }

    func setDestination(_ item: MKMapItem) {
        destination = item
        searchResults = []
        guard let from = LocationProvider.shared.location else { return }
        route(to: item, from: from)
    }

    private func route(to item: MKMapItem, from location: CLLocation) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = item
        request.transportType = .automobile
        MKDirections(request: request).calculate { [weak self] resp, _ in
            DispatchQueue.main.async {
                self?.route = resp?.routes.first
                self?.lastStepIndex = 0
                if let r = self?.route {
                    self?.remainingDistance = r.distance
                    self?.remainingTime = r.expectedTravelTime
                }
            }
        }
    }

    func cancel() {
        route = nil
        destination = nil
        currentInstruction = ""
        distanceToManeuver = 0
        remainingDistance = 0
        remainingTime = 0
    }

    // MARK: - 位置更新 → 算当前步骤

    private func onLocation(_ loc: CLLocation?) {
        guard let loc, let route = route else { return }

        // 找到当前所在的步骤（离该步骤折线最近）
        var bestIndex = lastStepIndex
        var bestDist = Double.greatestFiniteMagnitude
        for (i, step) in route.steps.enumerated() where !step.instructions.isEmpty {
            let d = distance(from: loc, to: step.polyline)
            if d < bestDist {
                bestDist = d
                bestIndex = i
            }
        }
        lastStepIndex = bestIndex

        let step = route.steps[bestIndex]
        currentInstruction = step.instructions.isEmpty ? "沿当前道路行驶" : step.instructions
        distanceToManeuver = max(0, distanceAlongPolyline(step.polyline, from: loc))

        // 剩余里程 = 当前步骤剩余 + 之后所有步骤长度
        var remain = max(0, step.distance - distanceToManeuver)
        for s in route.steps[(bestIndex + 1)...] {
            remain += s.distance
        }
        remainingDistance = remain
        if route.distance > 0 {
            let ratio = remain / route.distance
            remainingTime = route.expectedTravelTime * ratio
        }
    }

    private func distance(from loc: CLLocation, to line: MKPolyline) -> CLLocationDistance {
        distanceAlongPolyline(line, from: loc, measureWhole: true)
    }

    /// 返回：若 measureWhole 为 true，取点到折线的最近距离；
    /// 否则返回从折线起点沿折线走到最近点的长度（用于算"本步骤还剩多远"）
    private func distanceAlongPolyline(_ line: MKPolyline, from loc: CLLocation,
                                       measureWhole: Bool = false) -> CLLocationDistance {
        let pts = line.points()
        let n = line.pointCount
        guard n > 1 else { return 0 }

        var best = Double.greatestFiniteMagnitude
        var bestAlong: CLLocationDistance = 0
        var along: CLLocationDistance = 0

        for i in 0..<(n - 1) {
            let a = CLLocation(latitude: pts[i].coordinate.latitude,
                               longitude: pts[i].coordinate.longitude)
            let b = CLLocation(latitude: pts[i + 1].coordinate.latitude,
                               longitude: pts[i + 1].coordinate.longitude)
            let segLen = a.distance(from: b)
            let (projDist, projAlong) = project(point: loc, onSegmentFrom: a, to: b)
            if projDist < best {
                best = projDist
                bestAlong = along + projAlong
            }
            along += segLen
        }
        return measureWhole ? best : bestAlong
    }

    /// 点到线段的投影：返回 (垂距, 从线段起点到投影点的距离)
    private func project(point p: CLLocation, onSegmentFrom a: CLLocation,
                         to b: CLLocation) -> (CLLocationDistance, CLLocationDistance) {
        let segLen = max(a.distance(from: b), 0.0001)
        let bearingAB = a.coordinate.bearing(to: b.coordinate)
        let bearingAP = a.coordinate.bearing(to: p.coordinate)
        let ap = a.distance(from: p)
        // 角度差投影
        let angleDiff = (bearingAP - bearingAB) * .pi / 180
        let t = max(0, min(segLen, ap * cos(angleDiff)))
        // 用投影点到 p 的距离作为垂距
        let projCoord = a.coordinate.coordinate(at: t, bearing: bearingAB)
        let proj = CLLocation(latitude: projCoord.latitude, longitude: projCoord.longitude)
        return (p.distance(from: proj), t)
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

extension MKRoute {
    /// 路线总里程（含所有步骤）
    var totalSteps: [MKRoute.Step] { steps.filter { !$0.instructions.isEmpty } }
}
