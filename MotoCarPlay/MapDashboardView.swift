import SwiftUI
import UIKit
import CoreLocation
import AMapNaviKit

/// 高德地图画布（MAMapView，由 AMapNaviKit 透出）
struct AMapCanvas: UIViewRepresentable {
    func makeUIView(context: Context) -> MAMapView {
        let map = MAMapView(frame: .zero)
        map.showsUserLocation = true
        map.userTrackingMode = .follow
        map.mapType = .standard
        map.isShowTraffic = false
        map.showsCompass = false
        map.showsScale = false
        map.zoomLevel = 16
        return map
    }

    func updateUIView(_ map: MAMapView, context: Context) {}
}

/// 主界面：高德地图 + 车速/方向，左边缘右滑进多功能页
struct MapDashboardView: View {
    @StateObject private var model = NavigationModel()
    @StateObject private var location = LocationProvider.shared
    @ObservedObject private var navi = AMapNaviController.shared
    @Binding var searchRequested: Bool
    let onOpenApps: () -> Void

    @State private var showSearch = false

    var body: some View {
        ZStack {
            AMapCanvas()
                .ignoresSafeArea()

            if navi.isNavigating {
                NaviScreen()
                    .transition(.opacity)
                    .zIndex(2)
            } else {
                idleOverlay
            }

            // 左边缘右滑热区 → 多功能页
            if !navi.isNavigating {
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
            }
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

    // MARK: - 待机浮层

    private var idleOverlay: some View {
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

            Spacer(minLength: 0)

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
                .frame(maxWidth: 440)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.72)))
            }
            .buttonStyle(CardButton())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - 高德原生导航页

struct NaviScreen: View {
    @ObservedObject private var navi = AMapNaviController.shared
    @StateObject private var location = LocationProvider.shared

    var body: some View {
        ZStack {
            NaviDriveViewContainer()
                .ignoresSafeArea()

            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    SpeedCard(speedKmh: location.speedKmh, heading: location.heading)
                    Spacer(minLength: 0)

                    Button {
                        navi.stop()
                    } label: {
                        Text("结束导航")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Color.red.opacity(0.9)))
                    }
                    .buttonStyle(CardButton())
                }

                Spacer(minLength: 0)

                if navi.calculating {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("正在规划路线…")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.72)))
                }

                if let text = navi.statusText {
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.72)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .statusBarHidden()
    }
}

/// AMapNaviDriveView 容器：导航 UI 全部由高德 SDK 渲染
struct NaviDriveViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> AMapNaviDriveView {
        let view = AMapNaviDriveView(frame: .zero)
        AMapNaviController.shared.attach(view: view)
        return view
    }

    func updateUIView(_ uiView: AMapNaviDriveView, context: Context) {}

    static func dismantleUIView(_ uiView: AMapNaviDriveView, coordinator: ()) {
        AMapNaviController.shared.detach(view: uiView)
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

// MARK: - 搜索面板（高德 POI，选中即开始高德导航）

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
                        TextField("输入目的地，如：加油站 / 星巴克", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .focused($focused)
                            .submitLabel(.search)
                            .onSubmit { runSearch() }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08)))

                    Button("搜索") { runSearch() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.accent)

                    Button("取消") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                }

                if model.pois.isEmpty {
                    Text(model.searchFailed
                         ? "没搜到结果，换个关键词试试"
                         : "选中目的地后直接进入高德导航（车头向上、路口大图）")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(model.pois) { poi in
                                Button {
                                    dismiss()
                                    AMapNaviController.shared.beginNavigation(
                                        to: RouteDestination(name: poi.name,
                                                             coordinate: poi.coordinate))
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Theme.accent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(poi.name)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                            Text(poi.address.isEmpty
                                                 ? "距离 \(Int(poi.distance)) m"
                                                 : "\(poi.address) · \(Int(poi.distance)) m")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.5))
                                                .lineLimit(1)
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

    private func runSearch() {
        model.searchPOI(query, near: LocationProvider.shared.location)
    }
}
