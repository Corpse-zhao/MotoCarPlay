import SwiftUI
import MapKit

/// 地图画布：路线折线 + 跟随定位
struct MapCanvas: UIViewRepresentable {
    let route: MKRoute?
    let destination: MKMapItem?
    let navigating: Bool

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = navigating ? .followWithHeading : .follow
        map.isRotateEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.overrideUserInterfaceStyle = .dark
        map.tintColor = UIColor(Theme.accent)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })

        if let route = route {
            map.addOverlay(route.polyline, level: .aboveRoads)
            map.setVisibleMapRect(
                route.polyline.boundingMapRect.insetBy(dx: -120, dy: -120),
                edgePadding: UIEdgeInsets(top: 150, left: 160, bottom: 140, right: 120),
                animated: true)
        }
        if let placemark = destination?.placemark {
            map.addAnnotation(MKPlacemark(placemark: placemark))
        }
        map.userTrackingMode = navigating ? .followWithHeading : .follow
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

/// 主界面：全屏地图 + 车速/方向 + 导航指引，左边缘右滑进多功能页
struct MapDashboardView: View {
    @StateObject private var model = NavigationModel()
    @StateObject private var location = LocationProvider.shared
    @Binding var searchRequested: Bool
    let onOpenApps: () -> Void

    @State private var showSearch = false

    var body: some View {
        ZStack {
            MapCanvas(route: model.route, destination: model.destination, navigating: model.route != nil)
                .ignoresSafeArea()

            // 左边缘右滑热区 → 多功能页
            HStack(spacing: 0) {
                Color.black.opacity(0.001)
                    .frame(width: 30)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onEnded { value in
                                if value.translation.width > 40 { onOpenApps() }
                            }
                    )
                Spacer(minLength: 0)
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    SpeedCard(speedKmh: location.speedKmh, heading: location.heading)

                    Spacer(minLength: 0)

                    Button(action: onOpenApps) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.55))
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(width: 46, height: 46)
                    }
                    .buttonStyle(CardButton())
                }

                if model.route != nil {
                    guidanceBanner
                        .frame(maxWidth: 620)
                }

                Spacer(minLength: 0)

                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .sheet(isPresented: $showSearch) {
            SearchSheet(model: model)
        }
        .onChange(of: searchRequested) { requested in
            if requested {
                searchRequested = false
                showSearch = true
            }
        }
    }

    // MARK: - 转向横幅

    private var guidanceBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: model.currentSymbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Theme.warn)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(formatDistance(model.distanceToManeuver))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.warn)
                    Text(model.currentInstruction)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                if !model.nextInstruction.isEmpty {
                    Text("随后 · \(model.nextInstruction)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)

            if model.isRerouting {
                ProgressView()
                    .tint(.white)
                    .padding(.trailing, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.black.opacity(0.72)))
    }

    // MARK: - 底部

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if model.route != nil {
                HStack(spacing: 8) {
                    Text(formatDistance(model.remainingDistance))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("· 约 \(formatTime(model.remainingTime))")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.black.opacity(0.72)))

                Spacer(minLength: 0)

                Button {
                    model.cancel()
                } label: {
                    Text("结束导航")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.red.opacity(0.85)))
                }
                .buttonStyle(CardButton())
            } else {
                Button {
                    showSearch = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                        Text("搜索目的地")
                            .font(.system(size: 16, weight: .medium))
                        Spacer(minLength: 0)
                        Text("右滑进应用")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 420)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.72)))
                }
                .buttonStyle(CardButton())

                Spacer(minLength: 0)
            }
        }
    }

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

// MARK: - 车速 + 方向

struct SpeedCard: View {
    let speedKmh: Double
    let heading: Double

    /// 横屏下屏幕朝向 ≠ 手机顶部朝向，需要按界面方向做偏移修正
    private var screenUpHeading: Double? {
        guard heading >= 0 else { return nil }
        return (heading + Compass.screenUpOffset())
            .truncatingRemainder(dividingBy: 360)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: -2) {
                Text("\(Int(speedKmh))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("km/h")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 38)

            if let up = screenUpHeading {
                HStack(spacing: 8) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .rotationEffect(.degrees(-up))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(compassLabel(up))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("\(Int(up))°")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
            } else {
                Text("获取方向中…")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.55)))
    }

    private func compassLabel(_ degrees: Double) -> String {
        let labels = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        let idx = Int(((degrees + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return labels[(idx + 8) % 8]
    }
}

// MARK: - 搜索面板

struct SearchSheet: View {
    @ObservedObject var model: NavigationModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Wallpaper()
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                        TextField("输入目的地，如：加油站", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .focused($focused)
                            .onSubmit { model.search(query, near: LocationProvider.shared.location) }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08)))

                    Button("取消") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                }

                if model.searchResults.isEmpty {
                    Text("搜到目的地后直接在本 App 内出路线与转向提示，不会跳出应用")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(model.searchResults, id: \.self) { item in
                                Button {
                                    model.setDestination(item)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Theme.accent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name ?? "未知地点")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                            if let addr = item.placemark.title {
                                                Text(addr)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.5))
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06)))
                                }
                                .buttonStyle(CardButton())
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .preferredColorScheme(.dark)
        .onAppear { focused = true }
    }
}
