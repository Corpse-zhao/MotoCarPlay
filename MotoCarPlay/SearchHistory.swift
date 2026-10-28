import Foundation
import CoreLocation
import Combine

/// 搜索记录（UserDefaults 持久化，最近 20 条）
struct SearchRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let date: Date
}

final class SearchHistory: ObservableObject {
    static let shared = SearchHistory()

    @Published var records: [SearchRecord] = []

    private let key = "moto.search.history.v1"
    private let limit = 20

    private init() { load() }

    /// 新增/置顶一条记录（同名同地去重）
    func add(name: String, address: String, coordinate: CLLocationCoordinate2D) {
        guard !name.isEmpty else { return }
        records.removeAll {
            $0.name == name &&
            abs($0.latitude - coordinate.latitude) < 1e-6 &&
            abs($0.longitude - coordinate.longitude) < 1e-6
        }
        let record = SearchRecord(name: name,
                                  address: address,
                                  latitude: coordinate.latitude,
                                  longitude: coordinate.longitude,
                                  date: Date())
        records.insert(record, at: 0)
        if records.count > limit {
            records = Array(records.prefix(limit))
        }
        save()
    }

    func remove(_ record: SearchRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([SearchRecord].self, from: data) else { return }
        records = list
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
