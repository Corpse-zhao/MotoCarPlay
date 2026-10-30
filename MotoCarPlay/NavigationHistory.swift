import Foundation
import CoreLocation
import SwiftUI

/// 单次导航记录：起点 → 终点、距离、用时、速度
struct NavRecord: Codable, Identifiable {
    var id = UUID()
    let date: Date                  // 出发时间
    let startName: String
    let endName: String
    let distanceMeters: Double      // 实际行驶距离（GPS 累计）
    let durationSeconds: TimeInterval // 总用时（从发起导航到结束）
    let maxSpeedKmh: Double
    let avgSpeedKmh: Double
}

/// 导航历史存储 + 单次导航会话的实时统计
final class NavigationHistoryStore: ObservableObject {
    static let shared = NavigationHistoryStore()
    @Published private(set) var records: [NavRecord] = []

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("nav_history.json")
    }
    private static let maxRecords = 200

    private init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let list = try? JSONDecoder().decode([NavRecord].self, from: data) else { return }
        records = list
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    func clear() {
        records.removeAll()
        save()
    }

    // MARK: - 会话统计（由 AMapNaviController 喂数据）

    private var sessionStart: Date?
    private var startName = ""
    private var endName = ""
    private var distance: Double = 0
    private var maxSpeedKmh: Double = 0
    private var lastLocation: CLLocation?

    /// 发起导航时调用
    func begin(startLocation: CLLocation, endName: String) {
        sessionStart = Date()
        startName = "当前位置"
        self.endName = endName
        distance = 0
        maxSpeedKmh = 0
        lastLocation = startLocation
    }

    /// 导航中每个定位更新都喂进来（重复/静止位置自动不计距离）
    func update(location: CLLocation) {
        guard sessionStart != nil else { return }
        let kmh = max(0, location.speed) * 3.6
        maxSpeedKmh = max(maxSpeedKmh, kmh)
        if let last = lastLocation, location.speed > 1.0 {
            distance += last.distance(from: location)
        }
        lastLocation = location
    }

    /// 结束导航：有效行程（≥100 米或 ≥2 分钟）才入库，太短的（误触/算路失败）丢弃
    @discardableResult
    func finish() -> NavRecord? {
        guard let start = sessionStart else { return nil }
        sessionStart = nil
        let duration = Date().timeIntervalSince(start)
        guard distance >= 100 || duration >= 120 else { return nil }
        let avg = duration > 0 ? distance / duration * 3.6 : 0
        let rec = NavRecord(date: start,
                            startName: startName,
                            endName: endName,
                            distanceMeters: distance,
                            durationSeconds: duration,
                            maxSpeedKmh: maxSpeedKmh,
                            avgSpeedKmh: avg)
        records.insert(rec, at: 0)
        if records.count > Self.maxRecords {
            records.removeLast(records.count - Self.maxRecords)
        }
        save()
        return rec
    }
}

// MARK: - 历史记录页

struct HistoryView: View {
    @StateObject private var store = NavigationHistoryStore.shared
    @State private var confirmClear = false

    var body: some View {
        ZStack {
            Wallpaper()

            if store.records.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("还没有导航记录")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                    Text("完成一次导航后会自动记录\n起点、距离、用时和速度")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
            } else {
                List {
                    ForEach(store.records) { rec in
                        NavRecordRow(record: rec)
                            .listRowBackground(Color.white.opacity(0.05))
                            .listRowSeparatorTint(.white.opacity(0.1))
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("导航历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.records.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空") { confirmClear = true }
                        .foregroundColor(.red)
                }
            }
        }
        .alert("清空全部导航记录？", isPresented: $confirmClear) {
            Button("清空", role: .destructive) { store.clear() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可恢复")
        }
    }
}

struct NavRecordRow: View {
    let record: NavRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 路线：起点 → 终点
            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.accent)
                Text(record.startName)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                Text(record.endName)
                    .lineLimit(1)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)

            // 指标：距离 / 用时 / 均速 / 最高速
            HStack(spacing: 14) {
                metric("wifi", // placeholder replaced below
                       icon: "point.topleft.down.curvedto.point.bottomright.up",
                       value: distanceText(record.distanceMeters))
                metric("clock", icon: "clock", value: durationText(record.durationSeconds))
                metric("avg", icon: "speedometer", value: String(format: "%.0f km/h", record.avgSpeedKmh))
                metric("max", icon: "gauge.with.needle", value: String(format: "%.0f", record.maxSpeedKmh))
            }
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.7))

            Text(dateText(record.date))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 4)
    }

    private func metric(_ _: String, icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
            Text(value)
        }
    }

    private func distanceText(_ m: Double) -> String {
        m < 1000 ? String(format: "%.0f 米", m) : String(format: "%.1f 公里", m / 1000)
    }

    private func durationText(_ s: TimeInterval) -> String {
        let total = Int(s)
        if total < 60 { return "\(total) 秒" }
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? "\(h)时\(m)分" : "\(m) 分钟"
    }

    private func dateText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE HH:mm"
        return f.string(from: d)
    }
}
