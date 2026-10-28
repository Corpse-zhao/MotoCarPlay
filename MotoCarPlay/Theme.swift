import SwiftUI

/// 全局配色：仿 CarPlay 深色主题
enum Theme {
    static let bg = Color(red: 0.06, green: 0.06, blue: 0.07)
    static let card = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let cardPressed = Color(red: 0.18, green: 0.18, blue: 0.21)
    static let accent = Color(red: 0.20, green: 0.62, blue: 0.98)
    static let warn = Color(red: 0.98, green: 0.60, blue: 0.10)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)

    static let iconCorner: CGFloat = 18
}

/// 可复用的大按钮卡片（戴手套也能按）
struct BigCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.iconCorner)
                    .fill(tint.opacity(0.22))
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(tint)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
    }
}
