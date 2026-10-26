import Foundation
import Security

/// API keys for the AI generator live in the macOS Keychain only: never in UserDefaults, files or logs.
enum KeychainStore {
    private static let service = "app.voxel.launcher.ai"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    /// Checks for a saved key without reading it, so it never triggers a Keychain prompt.
    static func exists(_ account: String) -> Bool {
        var q = query(account)
        q[kSecReturnAttributes as String] = true
        return SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess
    }

    static func read(_ account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let updated = SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updated == errSecSuccess { return true }
        var q = query(account)
        q[kSecValueData as String] = data
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func remove(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}
