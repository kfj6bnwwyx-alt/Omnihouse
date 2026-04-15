//
//  NestProvider.swift
//  house connect
//
//  Concrete `AccessoryProvider` backed by the Google Smart Device
//  Management (SDM) REST API. Follows the SmartThingsProvider pattern:
//  disk cache for offline display, token refresh, typed errors,
//  optimistic UI updates after commands.
//
//  Requires:
//    - $5 Google Device Access Console registration
//    - OAuth 2.0 client credentials (project ID, client ID, client secret)
//    - User consent via NestOAuthView
//
//  When credentials are absent, the app falls back to DemoNestProvider
//  (see house_connectApp.swift).
//
//  Supported device types:
//    - Thermostat (temperature, humidity, HVAC mode, setpoint)
//    - Camera / Doorbell (presence only — no streaming in Phase 6)
//    - Display (informational)
//
//  NOT supported (not in SDM program):
//    - Nest Protect (smoke/CO) — use DemoNestProvider for UI development
//

import Foundation
import Observation

@MainActor
@Observable
final class NestProvider: AccessoryProvider {
    let id: ProviderID = .nest
    let displayName: String = "Google Nest"

    private(set) var homes: [Home] = []
    private(set) var rooms: [Room] = []
    private(set) var accessories: [Accessory] = []
    private(set) var authorizationState: ProviderAuthorizationState = .notDetermined

    private(set) var lastError: String?
    private(set) var isRefreshing: Bool = false
    private(set) var lastRefreshed: Date?

    @ObservationIgnored private let oauthManager: NestOAuthManager
    @ObservationIgnored private let client: NestSDMAPIClient
    @ObservationIgnored private let cache: NestAccessoryCache
    @ObservationIgnored private var didStart = false

    var projectID: String { oauthManager.projectID }

    // MARK: - OAuth delegation
    //
    // NestOAuthView talks to the provider (not to the manager directly) so
    // the manager can stay private. These methods forward to the manager.

    /// Builds the Google OAuth consent URL. The caller opens it in
    /// ASWebAuthenticationSession and captures the `code` from the
    /// redirect callback.
    func buildAuthorizationURL(redirectURI: String) -> URL? {
        oauthManager.buildAuthorizationURL(redirectURI: redirectURI)
    }

    /// Exchanges the authorization code returned from the consent flow
    /// for access + refresh tokens. Persists them to the Keychain.
    func exchangeOAuthCode(_ code: String, redirectURI: String) async throws {
        try await oauthManager.exchangeCode(code, redirectURI: redirectURI)
    }

    init(
        tokenStore: KeychainTokenStore,
        config: NestOAuthManager.Configuration,
        cache: NestAccessoryCache = .init()
    ) {
        let oauth = NestOAuthManager(config: config, tokenStore: tokenStore)
        self.oauthManager = oauth
        self.cache = cache
        self.client = NestSDMAPIClient(
            tokenProvider: { oauth.accessToken },
            tokenRefresher: { try await oauth.refreshAccessToken() }
        )
    }

    // MARK: - AccessoryProvider

    func start() async {
        guard !didStart else { return }
        didStart = true

        // Hydrate from disk cache immediately.
        if let cached = cache.load() {
            homes = cached.homes
            rooms = cached.rooms
            accessories = cached.accessories.map {
                var a = $0; a.isReachable = false; return a
            }
        }

        await refresh()
    }

    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws {
        precondition(accessoryID.provider == .nest,
                     "Routing bug: non-Nest ID sent to NestProvider")

        guard authorizationState == .authorized else {
            throw ProviderError.underlying(
                "Nest isn't connected. Go to Settings → Connections to sign in with Google."
            )
        }

        guard let sdm = NestCapabilityMapper.sdmCommand(
            for: command,
            currentMode: accessories.first(where: { $0.id == accessoryID })?.hvacMode
        ) else {
            throw ProviderError.unsupportedCommand
        }

        do {
            try await client.executeCommand(
                projectID: oauthManager.projectID,
                deviceID: accessoryID.nativeID,
                command: sdm.command,
                params: sdm.params
            )
        } catch let error as NestSDMError {
            throw ProviderError.underlying(error.localizedDescription)
        }

        // Optimistic: re-fetch just this device.
        await refreshDevice(nativeID: accessoryID.nativeID)
    }

    func rename(accessory accessoryID: AccessoryID, to newName: String) async throws {
        // SDM API doesn't support renaming devices — names are set in
        // the Google Home app. Surface a clear message.
        throw ProviderError.underlying("Device names are managed in the Google Home app.")
    }

    func removeAccessory(_ accessoryID: AccessoryID) async throws {
        precondition(accessoryID.provider == .nest)
        // SDM doesn't support device removal. Remove locally only.
        accessories.removeAll { $0.id == accessoryID }
    }

    /// Called when the user explicitly disconnects Nest from Settings.
    func disconnect() {
        oauthManager.clearTokens()
        cache.clear()
        homes = []
        rooms = []
        accessories = []
        authorizationState = .notDetermined
        lastError = nil
    }

    // MARK: - Refresh

    func refresh() async {
        guard oauthManager.hasTokens else {
            authorizationState = .notDetermined
            accessories = accessories.map {
                var a = $0; a.isReachable = false; return a
            }
            if accessories.isEmpty, let cached = cache.load() {
                homes = cached.homes
                rooms = cached.rooms
                accessories = cached.accessories.map {
                    var a = $0; a.isReachable = false; return a
                }
            }
            lastError = "Nest isn't connected — sign in with Google in Settings → Connections"
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let projectID = oauthManager.projectID

            // Fetch structures → homes
            let structures = try await client.fetchStructures(projectID: projectID)
            let builtHomes = structures.map { s in
                Home(
                    id: s.id,
                    name: s.displayName,
                    isPrimary: structures.first?.id == s.id,
                    provider: .nest
                )
            }

            // Fetch devices
            let devices = try await client.fetchDevices(projectID: projectID)

            // Build rooms from device parent relations (SDM doesn't have
            // a standalone rooms endpoint — rooms are inferred from
            // device parentRelations).
            var seenRooms: [String: Room] = [:]
            for device in devices {
                if let roomID = NestCapabilityMapper.roomID(for: device),
                   seenRooms[roomID] == nil {
                    let roomName = device.parentRelations?.first?.displayName ?? "Room"
                    let homeID = builtHomes.first?.id ?? ""
                    seenRooms[roomID] = Room(
                        id: roomID,
                        name: roomName,
                        homeID: homeID,
                        provider: .nest
                    )
                }
            }

            // Build accessories
            let built: [Accessory] = devices.map { device in
                let isOnline = device.trait("sdm.devices.traits.Connectivity")?
                    .string("status")?.uppercased() == "ONLINE"
                return Accessory(
                    id: AccessoryID(provider: .nest, nativeID: device.deviceID),
                    name: NestCapabilityMapper.displayName(for: device),
                    category: NestCapabilityMapper.category(for: device),
                    roomID: NestCapabilityMapper.roomID(for: device),
                    isReachable: isOnline,
                    capabilities: NestCapabilityMapper.capabilities(from: device)
                )
            }

            self.homes = builtHomes
            self.rooms = Array(seenRooms.values)
            self.accessories = built
            self.authorizationState = .authorized
            self.lastError = nil
            self.lastRefreshed = Date()

            cache.save(NestCacheSnapshot(
                homes: self.homes,
                rooms: self.rooms,
                accessories: built
            ))
        } catch let error as NestSDMError {
            self.lastError = error.localizedDescription
            if case .tokenExpired = error {
                self.authorizationState = .denied
                accessories = accessories.map {
                    var a = $0; a.isReachable = false; return a
                }
            } else if case .http(let status, _) = error, status == 401 || status == 403 {
                self.authorizationState = .denied
                accessories = accessories.map {
                    var a = $0; a.isReachable = false; return a
                }
            }
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    private func refreshDevice(nativeID: String) async {
        do {
            let device = try await client.fetchDevice(
                projectID: oauthManager.projectID,
                deviceID: nativeID
            )
            guard let index = accessories.firstIndex(where: { $0.id.nativeID == nativeID }) else {
                return
            }
            let old = accessories[index]
            let isOnline = device.trait("sdm.devices.traits.Connectivity")?
                .string("status")?.uppercased() == "ONLINE"
            accessories[index] = Accessory(
                id: old.id,
                name: old.name,
                category: old.category,
                roomID: old.roomID,
                isReachable: isOnline,
                capabilities: NestCapabilityMapper.capabilities(from: device)
            )
        } catch {
            self.lastError = "Device state may be outdated — pull to refresh"
        }
    }
}
