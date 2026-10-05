//
//  TokenStore.swift
//  iris
//

import Foundation
import Security
import Synchronization

/// The tokens of a signed-in device.
nonisolated struct StoredTokens: Codable, Equatable, Sendable {
    var refreshToken: String
    var refreshTokenExpiresAt: Date
    var accessToken: String?
    var accessTokenExpiresAt: Date?
}

/// Secure storage for the session tokens.
nonisolated protocol TokenStore: Sendable {
    func load() -> StoredTokens?
    func save(_ tokens: StoredTokens)
    func clear()
}

/// Keeps the tokens as one generic-password item, readable after the first unlock, never synced.
nonisolated struct KeychainTokenStore: TokenStore {
    var service = "com.atmosfera.iris.session"
    var account = "tokens"

    func load() -> StoredTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONCoding.decoder.decode(StoredTokens.self, from: data)
    }

    func save(_ tokens: StoredTokens) {
        guard let data = try? JSONCoding.encoder.encode(tokens) else { return }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

/// Token storage for previews and tests.
nonisolated final class InMemoryTokenStore: TokenStore {
    private let tokens: Mutex<StoredTokens?>

    init(_ tokens: StoredTokens? = nil) {
        self.tokens = Mutex(tokens)
    }

    func load() -> StoredTokens? { tokens.withLock { $0 } }
    func save(_ tokens: StoredTokens) { self.tokens.withLock { $0 = tokens } }
    func clear() { tokens.withLock { $0 = nil } }
}
