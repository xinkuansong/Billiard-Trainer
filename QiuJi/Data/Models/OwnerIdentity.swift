import Foundation

/// 用户数据的本地归属键。键带类型前缀，避免服务端 user id 与设备 UUID 碰撞。
enum OwnerKey {
    static let unassigned = "__unassigned__"

    static func guest(_ deviceGuestID: String) -> String {
        "guest:\(deviceGuestID)"
    }

    static func account(_ userID: String) -> String {
        "account:\(userID)"
    }

    static func isAccount(_ value: String) -> Bool {
        value.hasPrefix("account:") && value.count > "account:".count
    }
}

/// 与 `AuthState` 共用同一个 UserDefaults 键，保证游客身份与数据 owner 跨重启稳定。
enum DeviceGuestIdentity {
    static let defaultsKey = "auth.deviceGuestID"

    static func id(in defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: defaultsKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: defaultsKey)
        return created
    }

    static func ownerKey(in defaults: UserDefaults = .standard) -> String {
        OwnerKey.guest(id(in: defaults))
    }
}

/// 当前页面/仓储写入所使用的 owner。读写都在主线程调用；独立成对象便于测试注入。
@MainActor
final class CurrentOwnerContext: ObservableObject {
    static let shared = CurrentOwnerContext()

    @Published private(set) var ownerKey: String
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.ownerKey = DeviceGuestIdentity.ownerKey(in: defaults)
    }

    func useGuest() {
        ownerKey = DeviceGuestIdentity.ownerKey(in: defaults)
    }

    var guestOwnerKey: String {
        DeviceGuestIdentity.ownerKey(in: defaults)
    }

    func useAccount(userID: String) {
        ownerKey = OwnerKey.account(userID)
    }

    /// 测试和迁移工具使用；生产身份切换应走 `useGuest` / `useAccount`。
    func setOwnerKey(_ ownerKey: String) {
        precondition(!ownerKey.isEmpty && ownerKey != OwnerKey.unassigned)
        self.ownerKey = ownerKey
    }
}
