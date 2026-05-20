import Foundation
import Security

/// Thread-safe Keychain-backed session token store with in-memory caching.
///
/// `loadTokens()` was previously hitting securityd (via SecItemCopyMatching → XPC)
/// on EVERY API request — and was being called from DiaryAPI, ImageAPI, AuthManager,
/// and EditorAutosaveService. Now the result is cached in-memory; only the first
/// load after launch (and reads after a `saveTokens` / `deleteTokens`) actually
/// touch the keychain.
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.calcalcal.app"
    private let account = "auth_tokens"

    // Serialize all access to the in-memory cache.
    private let cacheQueue = DispatchQueue(label: "com.calcalcal.app.keychain.cache")
    private var cachedSession: Session??  // double-optional: outer = "have we ever loaded?", inner = "did keychain have a value?"

    private init() {}

    func saveTokens(_ session: Session) throws {
        let data = try JSONEncoder().encode(session)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Delete existing tokens first
        SecItemDelete(query as CFDictionary)

        // Save new tokens
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }

        cacheQueue.sync {
            cachedSession = .some(session)
        }
    }

    func loadTokens() throws -> Session? {
        // Fast path: serve from in-memory cache.
        if let cached = cacheQueue.sync(execute: { cachedSession }) {
            return cached
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            cacheQueue.sync { cachedSession = .some(nil) }
            return nil
        }

        let session = try JSONDecoder().decode(Session.self, from: data)
        cacheQueue.sync { cachedSession = .some(session) }
        return session
    }

    func deleteTokens() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }

        cacheQueue.sync {
            cachedSession = .some(nil)
        }
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
}
