import Foundation
import MapKit
import Combine

/// 搜索目的地 → 规划路线 → 实时转向指引 + 偏航重算
final class NavigationModel: NSObject, ObservableObject {
    @Published var searchResults: [MKMapItem] = []
    @Published var route: MKRoute?
    @Published var destination: MKMapItem?

    @Published var currentSymbol = "arrow.up"
    @Published var currentInstruction = ""
    @Published var nextInstruction = ""
    @Published var distanceToManeuver: CLLocationDistance = 0
    @Published var remainingDistance: CLLocationDistance = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var isRerouting = false

    private var cancellables = Set<AnyCancellable>()
    private var lastStepIndex = 0
    private var lastRerouteAt = Date.distantPast
    private var hasGuidance = false

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
        hasGuidance = false
        guard let from = LocationProvider.shared.location else { return }
        calculateRoute(to: item, from: from)
    }

    private func calculateRoute(to item: MKMapItem, from location: CLLocation) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = item
        request.transportType = .automobile
        MKDirections(request: request).calculate { [weak self] resp, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRerouting = false
                if let route = resp?.routes.first {
                    self.route = route
                    self.initializeGuidance()
                } else if self.route == nil {
                    self.currentSymbol = "exclamationmark.triangle"
                    self.currentInstruction = "路线规划失败：\(error?.localizedDescription ?? "未知错误")"
                }
                // 偏航重算失败时保留旧路线继续用
            }
        }
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

    /// 路线算完立即初始化指引（不等 GPS 移动），静止时也能看到第一步
    private func initializeGuidance() {
        guard let route = route else { return }
        remainingDistance = route.distance
        remainingTime = route.expectedTravelTime
        lastStepIndex = 0
        hasGuidance = true

        if let first = route.steps.first(where: { !$0.instructions.isEmpty }) {
            currentSymbol = Self.symbol(for: first.instructions)
            currentInstruction = first.instructions
            distanceToManeuver = first.distance
        } else {
            currentSymbol = "arrow.up"
            currentInstruction = "沿路线出发"
            distanceToManeuver = route.distance
        }
        // 用最后一次定位先算一遍，不必等下一次 GPS 更新
        if let loc = LocationProvider.shared.location {
            updateGuidance(with: loc)
        }
    }

    private func onLocation(_ loc: CLLocation?) {
        guard let loc, let route = route else { return }

        // 偏航检测：偏离路线超过 80m 触发重算（10 秒冷却）
        if hasGuidance, let dest = destination,
           distance(from: loc, to: route.polyline) > 80,
           Date().timeIntervalSince(lastRerouteAt) > 10 {
            lastRerouteAt = Date()
            isRerouting = true
            calculateRoute(to: dest, from: loc)
            return
        }
        updateGuidance(with: loc)
    }

    private func updateGuidance(with loc: CLLocation) {
        guard let route = route else { return }

        // 找到当前所在步骤（离该步骤折线最近）
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
        currentSymbol = Self.symbol(for: currentInstruction)
        distanceToManeuver = max(0, distanceAlongPolyline(step.polyline, from: loc))

        // 下一步预告
        if let next = route.steps[(bestIndex + 1)...].first(where: { !$0.instructions.isEmpty }) {
            nextInstruction = next.instructions
        } else {
            nextInstruction = ""
        }

        // 剩余里程 = 当前步骤剩余 + 之后所有步骤长度
        var remain = max(0, step.distance - distanceToManeuver)
        for s in route.steps[(bestIndex + 1)...] {
            remain += s.distance
        }
        remainingDistance = remain
        if route.distance > 0 {
            remainingTime = route.expectedTravelTime * (remain / route.distance)
        }
    }

    // MARK: - 转向图标

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

    // MARK: - 几何工具

    private func distance(from loc: CLLocation, to line: MKPolyline) -> CLLocationDistance {
        distanceAlongPolyline(line, from: loc, measureWhole: true)
    }

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
                               longitude: pts[i + 0].coordinate.longitude)
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

    private func project(point p: CLLocation, onSegmentFrom a: CLLocation,
                         to b: CLLocation) -> (CLLocationDistance, CLLocationDistance) {
        let segLen = max(a.distance(from: b), 0.0001)
        let bearingAB = a.coordinate.bearing(to: b.coordinate)
        let bearingAP = a.coordinate.bearing(to: p.coordinate)
        let ap = a.distance(from: p)
        let angleDiff = (bearingAP - bearingAB) * .pi / 180
        let t = max(0, min(segLen, ap * cos(angleDiff)))
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
