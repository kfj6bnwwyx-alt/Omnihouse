//
//  KeychainTokenStore.swift
//  house connect
//
//  Central place to read/write/delete per-provider secrets (access tokens,
//  PATs, refresh tokens, etc.). Everything is stored in the iOS Keychain via
//  KeychainAccess so tokens survive app launches without ever touching
//  UserDefaults or a plist on disk.
//
//  Design notes:
//    - One Keychain service name per app bundle. All keys live inside it.
//    - Keys are strongly typed via `TokenKey` so we never fat-finger a string.
//    - Store returns `nil` on miss rather than throwing — callers decide
//      whether "no token yet" is an error or just means "not configured".
//    - Write errors ARE thrown because silently losing a token the user just
//      pasted would be worse than a loud crash log.
//

import Foundation
import KeychainAccess

@MainActor
final class KeychainTokenStore {
    /// Namespaced service so it can never collide with a system keychain item.
    /// Matches the actual bundle ID (`house-connect.house-connect`) rather
    /// than the aspirational reverse-DNS name.
    ///
    /// `nonisolated` so it can be referenced as a default argument to `init`
    /// from non-main-actor contexts. This is an immutable `let` holding a
    /// string literal — there's no real isolation to break.
    nonisolated static let service = "house-connect.house-connect.tokens"

    /// Strongly-typed list of everything we ever store in the keychain.
    /// Add a new case instead of passing raw strings around.
    enum TokenKey: String {
        case smartThingsPAT
        /// Google OAuth 2.0 access token for the Nest SDM API. Expires
        /// hourly; the `NestOAuthManager` handles refresh transparently.
        case nestAccessToken
        /// Google OAuth 2.0 refresh token. Long-lived but may rotate
        /// on each refresh — always persist the latest one.
        case nestRefreshToken
        /// Home Assistant long-lived access token. Created in HA's user
        /// profile page. Valid for 10 years.
        case homeAssistantToken
        /// Home Assistant local server URL (e.g. "http://192.168.4.23:8123").
        /// Used when on the same Wi-Fi network — fastest path.
        case homeAssistantURL
        /// Home Assistant remote/Tailscale URL (e.g. "http://100.67.208.9:8123").
        /// Fallback when local URL is unreachable (away from home).
        case homeAssistantRemoteURL
    }

    private let keychain: Keychain

    init(service: String = KeychainTokenStore.service) {
        self.keychain = Keychain(service: service)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
            .synchronizable(false)
    }

    // MARK: - Read / write / delete

    func token(for key: TokenKey) -> String? {
        try? keychain.get(key.rawValue)
    }

    func set(_ value: String, for key: TokenKey) throws {
        try keychain.set(value, key: key.rawValue)
    }

    func delete(_ key: TokenKey) throws {
        try keychain.remove(key.rawValue)
    }

    func hasToken(for key: TokenKey) -> Bool {
        (token(for: key)?.isEmpty == false)
    }
}
