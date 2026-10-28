import SwiftUI
import Contacts
import UIKit

/// 通讯录加载：只读带号码的联系人
final class ContactsModel: ObservableObject {
    @Published var contacts: [CNContact] = []
    @Published var hint: String = ""
    @Published var denied = false

    func load() {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .denied || status == .restricted {
            denied = true
            hint = "通讯录未授权。去 设置 → 隐私与安全性 → 通讯录 打开本 App"
            return
        }
        store.requestAccess(for: .contacts) { [weak self] granted, _ in
            guard granted else {
                DispatchQueue.main.async {
                    self?.denied = true
                    self?.hint = "通讯录未授权。去 设置 → 隐私与安全性 → 通讯录 打开本 App"
                }
                return
            }
            let keys: [CNKeyDescriptor] = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .givenName
            var list: [CNContact] = []
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    if !contact.phoneNumbers.isEmpty { list.append(contact) }
                }
            } catch {
                DispatchQueue.main.async { self?.hint = "读取通讯录失败：\(error.localizedDescription)" }
                return
            }
            DispatchQueue.main.async {
                self?.contacts = list
                self?.hint = list.isEmpty ? "通讯录中没有带号码的联系人" : ""
            }
        }
    }
}

/// CarPlay 风格电话页：左联系人 / 右拨号盘
struct PhoneView: View {
    @StateObject private var model = ContactsModel()
    @Environment(\.dismiss) private var dismiss
    @State private var number = ""
    @State private var pendingCall: PendingCall?

    private struct PendingCall: Identifiable {
        let id = UUID()
        let name: String
        let number: String
    }

    var body: some View {
        ZStack {
            Wallpaper()

            HStack(spacing: 16) {
                contactsPane
                keypadPane
            }
            .padding(.horizontal, 22)
            .padding(.top, 34)
            .padding(.bottom, 16)

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(CardButton())
                    Spacer()
                    Text("电话")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Color.clear.frame(width: 74, height: 1)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                Spacer()
            }
        }
        .statusBarHidden()
        .onAppear { model.load() }
        .alert(item: $pendingCall) { call in
            Alert(title: Text("拨打 \(call.name)"),
                  message: Text(call.number),
                  primaryButton: .default(Text("呼叫")) { dial(call.number) },
                  secondaryButton: .cancel(Text("取消")))
        }
    }

    // MARK: - 通讯录

    private var contactsPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("通讯录")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            if !model.hint.isEmpty {
                Text(model.hint)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 6)
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(model.contacts, id: \.identifier) { contact in
                        let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "未命名"
                        let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
                        Button {
                            pendingCall = PendingCall(name: name, number: phone)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color(red: 0.30, green: 0.85, blue: 0.42).opacity(0.22))
                                    Text(String(name.prefix(1)))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(red: 0.45, green: 0.92, blue: 0.55))
                                }
                                .frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(phone)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.45, green: 0.92, blue: 0.55))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(CardButton())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 拨号盘

    private var keypadPane: some View {
        VStack(spacing: 10) {
            Text(number.isEmpty ? "输入号码" : number)
                .font(.system(size: number.isEmpty ? 20 : 30, weight: .semibold, design: .rounded))
                .foregroundColor(number.isEmpty ? .white.opacity(0.35) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)

            let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(keys, id: \.self) { key in
                    Button {
                        number.append(key)
                    } label: {
                        Text(key)
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(CardButton())
                }
            }

            HStack(spacing: 10) {
                Button {
                    if !number.isEmpty { number.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 56, height: 48)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(CardButton())

                Button {
                    guard !number.isEmpty else { return }
                    pendingCall = PendingCall(name: "号码", number: number)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                        Text("呼叫")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.72, blue: 0.33)))
                }
                .buttonStyle(CardButton())
                .disabled(number.isEmpty)
                .opacity(number.isEmpty ? 0.45 : 1)
            }
        }
        .frame(width: 300)
    }

    private func dial(_ raw: String) {
        let digits = raw.filter { "0123456789+*#".contains($0) }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }
}
