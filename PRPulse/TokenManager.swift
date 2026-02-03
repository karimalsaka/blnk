import Foundation
import Security

final class TokenManager {
    static let shared = TokenManager()
    private let key = "github-pat"
    private let service = Bundle.main.bundleIdentifier ?? "com.prpulse.app"

    private init() {}

    func saveToken(_ token: String) -> Bool {
        let saved = storeToken(token)
        NotificationPreferences.baselineEstablished = false
        return saved
    }

    func getToken() -> String? {
        readToken()
    }

    @discardableResult
    func deleteToken() -> Bool {
        let deleted = deleteStoredToken()
        NotificationPreferences.baselineEstablished = false
        return deleted
    }

    var hasToken: Bool {
        guard let token = getToken() else { return false }
        return !token.isEmpty
    }

    private func storeToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return true
        }
        if status != errSecItemNotFound {
            return false
        }
        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    private func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteStoredToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

}
