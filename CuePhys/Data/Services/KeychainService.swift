import Foundation
import Security

enum KeychainService {
    enum Key: String {
        case appleUserID = "com.youbilliards.cuephys.apple_user_id"
        case appleIdentityToken = "com.youbilliards.cuephys.apple_identity_token"
        case accessToken = "com.youbilliards.cuephys.access_token"
        case refreshToken = "com.youbilliards.cuephys.refresh_token"
        case trustedLocalAccount = "com.youbilliards.cuephys.trusted_local_account"
    }

    // Compatibility lookup only within the current signed keychain access group.
    // A changed Bundle ID does not grant access to another app's credentials.
    // New writes use CuePhys; missing credentials follow normal sign-in.
    private static let legacyPrefix = "com.qiuji.app."

    private static func legacyRawValue(for key: Key) -> String {
        legacyPrefix + key.rawValue.replacingOccurrences(of: "com.youbilliards.cuephys.", with: "")
    }

    private static func query(for rawValue: String, returningData: Bool = false) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: rawValue
        ]
        if returningData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return query
    }

    @discardableResult
    static func save(key: Key, value: String) -> Bool {
        let data = Data(value.utf8)
        let query = query(for: key.rawValue)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update != errSecItemNotFound { return update == errSecSuccess }
        let status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load(key: Key) -> String? {
        for rawValue in [key.rawValue, legacyRawValue(for: key)] {
            var result: AnyObject?
            let status = SecItemCopyMatching(query(for: rawValue, returningData: true) as CFDictionary, &result)
            if status == errSecSuccess, let data = result as? Data,
               let value = String(data: data, encoding: .utf8) {
                return value
            }
        }
        return nil
    }

    @discardableResult
    static func delete(key: Key) -> Bool {
        let statuses = [key.rawValue, legacyRawValue(for: key)].map {
            SecItemDelete(query(for: $0) as CFDictionary)
        }
        return statuses.contains(errSecSuccess)
    }

    static func clearAll() {
        Key.allCases.forEach { delete(key: $0) }
    }
}

extension KeychainService.Key: CaseIterable {}
