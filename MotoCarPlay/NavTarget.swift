import Foundation
import MapKit
import UIKit

/// 导航目的地投递方式：默认交给高德，未安装则回落内置地图
enum NavTarget: String, CaseIterable, Identifiable {
    case amap
    case apple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .amap: return "高德地图"
        case .apple: return "内置地图"
        }
    }

    var subtitle: String {
        switch self {
        case .amap: return "跳转高德开始导航（车道级 / 电子眼更全）"
        case .apple: return "App 内直接显示路线与转向提示"
        }
    }

    /// 尝试把目的地交给外部导航 App，成功返回 true
    func handoff(to item: MKMapItem) -> Bool {
        guard self == .amap else { return false }
        let coord = item.placemark.coordinate
        let name = (item.name ?? "目的地").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "目的地"
        // 高德使用 GCJ-02；国内 Apple 地图数据同样为 GCJ-02，可直接透传
        let urlString = String(format: "iosamap://path?sourceApplication=MotoCarPlay&dlat=%.6f&dlon=%.6f&dname=%@&dev=0&t=0",
                               coord.latitude, coord.longitude, name)
        guard let url = URL(string: urlString) else { return false }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }
        return false
    }

    var isInstalled: Bool {
        guard self == .amap else { return true }
        return UIApplication.shared.canOpenURL(URL(string: "iosamap://")!)
    }
}
