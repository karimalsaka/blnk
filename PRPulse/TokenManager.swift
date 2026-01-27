import Foundation

final class TokenManager {
    static let shared = TokenManager()
    private let key = "github-pat"

    private init() {}

    func saveToken(_ token: String) -> Bool {
        UserDefaults.standard.set(token, forKey: key)
        return true
    }

    func getToken() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    @discardableResult
    func deleteToken() -> Bool {
        UserDefaults.standard.removeObject(forKey: key)
        return true
    }

    var hasToken: Bool {
        guard let token = getToken() else { return false }
        return !token.isEmpty
    }
}
