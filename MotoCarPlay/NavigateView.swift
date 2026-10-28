import SwiftUI
import MapKit

/// MKMapView 包装：路线折线 + 跟随用户位置
struct RouteMapView: UIViewRepresentable {
    let route: MKRoute?
    let destination: MKMapItem?
    let followUser: Bool

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = followUser ? .followWithHeading : .none
        map.isRotateEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.tintColor = UIColor(Theme.accent)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        if let route = route {
            map.addOverlay(route.polyline, level: .aboveRoads)
            map.setVisibleMapRect(
                route.polyline.boundingMapRect.insetBy(dx: -80, dy: -80),
                edgePadding: UIEdgeInsets(top: 140, left: 30, bottom: 110, right: 30),
                animated: true)
        }
        if let placemark = destination?.placemark {
            map.addAnnotation(MKPlacemark(placemark: placemark))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor(Theme.accent)
            renderer.lineWidth = 8
            renderer.lineCap = .round
            return renderer
        }
    }
}

struct NavigateView: View {
    @StateObject private var model = NavigationModel()
    @StateObject private var location = LocationProvider.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        ZStack {
            RouteMapView(
                route: model.route,
                destination: model.destination,
                followUser: model.route != nil)
            .ignoresSafeArea()

            VStack {
                // 顶部转向横幅（类似 CarPlay 导航卡）
                if model.route != nil {
                    guidanceBanner
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                }
                Spacer()

                // 底部：搜索框 / 结果列表 / 剩余信息
                VStack(spacing: 10) {
                    if model.route != nil {
                        bottomBar
                    } else {
                        searchPanel
                    }
                }
                .padding(14)
            }
        }
        .onAppear { location.start() }
    }

    // MARK: - 横幅

    private var guidanceBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(formatDistance(model.distanceToManeuver))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.warn)
                Text(model.currentInstruction)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card.opacity(0.96)))
    }

    private var bottomBar: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDistance(model.remainingDistance))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text("剩余 · 约 \(formatTime(model.remainingTime))")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button {
                model.cancel()
            } label: {
                Text("结束")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.red.opacity(0.9)))
            }
            .buttonStyle(CardButton())
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card.opacity(0.96)))
    }

    // MARK: - 搜索面板

    private var searchPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                TextField("输入目的地，如：加油站", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    .onSubmit { model.search(query, near: location.location) }
                Button {
                    model.search(query, near: location.location)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .frame(width: 44, height: 44)
                }
            }

            if !model.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(model.searchResults, id: \.self) { item in
                        Button {
                            model.setDestination(item)
                        } label: {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(Theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "未知地点")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)
                                    if let addr = item.placemark.title {
                                        Text(addr)
                                            .font(.system(size: 13))
                                            .foregroundColor(Theme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                        }
                        .buttonStyle(CardButton())
                        Divider().opacity(0.15)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                .frame(maxHeight: 260)
            }
        }
    }

    // MARK: - 格式化

    private func formatDistance(_ d: CLLocationDistance) -> String {
        if d < 0 { return "--" }
        if d < 1000 { return "\(Int(d / 10) * 10) m" }
        return String(format: "%.1f km", d / 1000)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        guard t > 0 else { return "--" }
        let m = Int(t / 60)
        if m < 60 { return "\(m) 分钟" }
        return "\(m / 60) 小时 \(m % 60) 分"
    }
}
