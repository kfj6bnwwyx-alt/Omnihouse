//
//  HomeAssistantProvider.swift
//  house connect
//
//  AccessoryProvider implementation backed by a Home Assistant instance.
//  Connects via WebSocket for real-time state updates and routes commands
//  through HA's service call API.
//
//  This single provider replaces the need for separate SmartThings, Nest,
//  and Sonos providers — HA handles all integrations natively, and we
//  consume its unified entity model.
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeAssistantProvider: NSObject, AccessoryProvider, HomeAssistantWebSocketDelegate {
    let id: ProviderID = .homeAssistant
    let displayName: String = "Home Assistant"

    // MARK: - Observable state (AccessoryProvider)

    private(set) var homes: [Home] = []
    private(set) var rooms: [Room] = []
    private(set) var accessories: [Accessory] = []
    private(set) var authorizationState: ProviderAuthorizationState = .notDetermined

    // MARK: - HA-specific observable state

    /// Last error for UI display.
    private(set) var lastError: String?
    /// Whether a refresh is in progress.
    private(set) var isRefreshing: Bool = false
    /// Timestamp of last successful state sync.
    private(set) var lastRefreshed: Date?
    /// HA server version string.
    private(set) var haVersion: String?
    /// Whether the WebSocket is connected.
    private(set) var isConnected: Bool = false

    /// Timestamp of the most recent successful WebSocket connection.
    /// Set on `didConnect`, cleared on `disconnect()`. Used by the
    /// diagnostics screen to show "Connected for Xh Ym".
    private(set) var connectedAt: Date?

    /// Timestamp of the most recent inbound state change or full state
    /// dump. Lets the diagnostics screen show "Last state update: 4s ago"
    /// as a cheap liveness signal without any extra plumbing.
    private(set) var lastStateUpdateAt: Date?

    /// HA scenes (scene.* entities) available for activation.
    private(set) var scenes: [HAScene] = []

    /// HA automations (automation.* entities) available for triggering.
    private(set) var automations: [HAAutomation] = []

    // MARK: - Internal state

    @ObservationIgnored private let tokenStore: KeychainTokenStore
    @ObservationIgnored private var wsClient: HomeAssistantWebSocketClient?
    @ObservationIgnored private var restClient: HomeAssistantRESTClient?
    @ObservationIgnored private var pingTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRebuildTask: Task<Void, Never>?

    /// entity_id → HAEntityState cache. Updated in real time via WebSocket.
    @ObservationIgnored private var entityStates: [String: HAEntityState] = [:]

    /// HA device registry: device_id → HADevice.
    @ObservationIgnored private var deviceRegistry: [String: HADevice] = [:]

    /// HA entity registry: entity_id → HAEntityRegistryListEntry.
    @ObservationIgnored private var entityRegistry: [String: HAEntityRegistryListEntry] = [:]

    /// HA area registry: area_id → HAArea.
    @ObservationIgnored private var areaRegistry: [String: HAArea] = [:]

    /// SmartThings companion entities for Frame TVs, keyed by the
    /// Frame's `media_player` entity_id. When the user has set up the
    /// SmartThings integration alongside the core Samsung Tizen one, HA
    /// exposes extra entities (`number.<tv>_art_brightness`,
    /// `select.<tv>_art_color_temperature`, `switch.<tv>_art_mode`) all
    /// tagged with the same `device_id`. We detect them during
    /// `rebuildAccessories()` and cache the mapping so the Frame TV
    /// detail view can unlock the art-brightness / color-temperature
    /// sliders when a companion is present.
    @ObservationIgnored private(set) var frameTVCompanions: [String: FrameTVSmartThingsCompanion] = [:]

    /// Companion-entity bundle linked to a Frame TV. Present fields
    /// indicate capabilities we can route; nil fields mean the user
    /// hasn't exposed that particular SmartThings entity.
    struct FrameTVSmartThingsCompanion: Sendable, Equatable {
        /// `number.<tv>_art_brightness` — 0–100 art-mode brightness.
        var artBrightnessEntityID: String?
        /// `select.<tv>_art_color_temperature` — warm/neutral/cool select.
        var artColorTemperatureEntityID: String?
    }

    /// Look up the SmartThings companion for a Frame TV's media_player
    /// entity. Returns nil if the user doesn't have the SmartThings
    /// integration set up (or the Frame isn't a recognised match).
    func frameTVSmartThingsCompanion(forMediaPlayerEntityID entityID: String) -> FrameTVSmartThingsCompanion? {
        frameTVCompanions[entityID]
    }

    /// Set the Frame's art-mode brightness (0.0–1.0) via the
    /// companion `number.<tv>_art_brightness` entity. Throws if no
    /// companion is registered or the provider isn't connected.
    /// Sits alongside `execute(_:on:)` instead of routing through
    /// `AccessoryCommand` because the Capability/Command enums are
    /// exhaustive across every provider — adding a case touches nine
    /// provider switches. Keeping this method local to the HA provider
    /// is the narrowest change that unlocks the slider.
    func setArtBrightness(_ value: Double, forMediaPlayerEntityID mediaPlayerEntityID: String) async throws {
        guard let companion = frameTVCompanions[mediaPlayerEntityID],
              let numberEntity = companion.artBrightnessEntityID else {
            throw ProviderError.unsupportedCommand
        }
        // HA's number.set_value expects the entity's native unit —
        // for SmartThings art_brightness that's 0–100.
        let clamped = max(0.0, min(1.0, value))
        let haValue = clamped * 100.0

        if let ws = wsClient, isConnected {
            try await ws.callService(
                domain: "number",
                service: "set_value",
                data: ["value": .double(haValue)],
                entityID: numberEntity
            )
        } else if let rest = restClient {
            try await rest.callService(
                domain: "number",
                service: "set_value",
                data: ["value": haValue],
                entityID: numberEntity
            )
        } else {
            throw ProviderError.notAuthorized
        }
    }

    /// Set the Frame's art-mode color temperature via the companion
    /// `select.<tv>_art_color_temperature` entity. Accepts the raw
    /// option string ("warm"/"standard"/"cool" — varies by firmware).
    /// Throws if no companion is registered or the provider isn't
    /// connected.
    func setArtColorTemperature(_ option: String, forMediaPlayerEntityID mediaPlayerEntityID: String) async throws {
        guard let companion = frameTVCompanions[mediaPlayerEntityID],
              let selectEntity = companion.artColorTemperatureEntityID else {
            throw ProviderError.unsupportedCommand
        }
        if let ws = wsClient, isConnected {
            try await ws.callService(
                domain: "select",
                service: "select_option",
                data: ["option": .string(option)],
                entityID: selectEntity
            )
        } else if let rest = restClient {
            try await rest.callService(
                domain: "select",
                service: "select_option",
                data: ["option": option],
                entityID: selectEntity
            )
        } else {
            throw ProviderError.notAuthorized
        }
    }

    /// Domains we care about. Entities outside these are ignored to keep
    /// the accessory list focused on controllable devices.
    private static let supportedDomains: Set<String> = [
        "light", "switch", "climate", "media_player", "camera",
        "fan", "cover", "lock", "binary_sensor", "sensor"
    ]

    /// Sensor device classes we include. Most sensors are noise (uptime,
    /// CPU temp, etc.); we only pull in the useful ones.
    private static let includedSensorClasses: Set<String> = [
        "temperature", "humidity", "battery", "motion", "occupancy",
        "presence", "door", "window", "garage_door", "opening",
        "smoke", "carbon_monoxide", "co"
    ]

    init(tokenStore: KeychainTokenStore) {
        self.tokenStore = tokenStore
        super.init()
    }

    // MARK: - AccessoryProvider

    func start() async {
        guard let token = tokenStore.token(for: .homeAssistantToken) else {
            authorizationState = .notDetermined
            return
        }

        // Collect candidate URLs: local first (fastest), remote/Tailscale as fallback.
        var candidates: [(label: String, url: URL)] = []
        if let local = tokenStore.token(for: .homeAssistantURL),
           let url = URL(string: local) {
            candidates.append(("local", url))
        }
        if let remote = tokenStore.token(for: .homeAssistantRemoteURL),
           let url = URL(string: remote) {
            candidates.append(("remote", url))
        }

        guard !candidates.isEmpty else {
            authorizationState = .notDetermined
            lastError = "No Home Assistant URL configured"
            return
        }

        // Try each URL in order — first reachable one wins.
        var connectedURL: URL?
        for (label, url) in candidates {
            let testClient = HomeAssistantRESTClient(baseURL: url, token: token)
            let reachable = await testClient.checkConnection()
            if reachable {
                #if DEBUG
                print("[ha.provider] connected via \(label): \(url)")
                #endif
                connectedURL = url
                break
            } else {
                #if DEBUG
                print("[ha.provider] \(label) unreachable: \(url)")
                #endif
            }
        }

        guard let baseURL = connectedURL else {
            let urls = candidates.map(\.url.absoluteString).joined(separator: ", ")
            authorizationState = .unavailable(reason: "Can't reach Home Assistant")
            lastError = "Tried \(urls) — all unreachable. Check your network."
            return
        }

        let rest = HomeAssistantRESTClient(baseURL: baseURL, token: token)
        restClient = rest

        // Fetch config for the home name
        if let config = try? await rest.getConfig() {
            haVersion = config.version
            let homeName = config.locationName ?? "Home"
            homes = [Home(id: "ha.home", name: homeName, isPrimary: true, provider: .homeAssistant)]
        }

        // Connect WebSocket
        let ws = HomeAssistantWebSocketClient(serverURL: baseURL, token: token)
        wsClient = ws
        await ws.connect(delegate: self)
    }

    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws {
        guard let ws = wsClient, isConnected else {
            // Fall back to REST if WebSocket is down
            guard let rest = restClient else { throw ProviderError.notAuthorized }
            let entityID = accessoryID.nativeID
            guard let entity = entityStates[entityID] else {
                throw ProviderError.accessoryNotFound
            }
            let call = HomeAssistantCapabilityMapper.serviceCall(for: command, entity: entity)
            try await rest.callService(
                domain: call.domain,
                service: call.service,
                data: call.data.mapValues { encodableToAny($0) },
                entityID: entityID
            )
            return
        }

        let entityID = accessoryID.nativeID
        guard let entity = entityStates[entityID] else {
            throw ProviderError.accessoryNotFound
        }

        let call = HomeAssistantCapabilityMapper.serviceCall(for: command, entity: entity)
        try await ws.callService(
            domain: call.domain,
            service: call.service,
            data: call.data,
            entityID: entityID
        )
    }

    func refresh() async {
        guard isRefreshing == false else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if let ws = wsClient, isConnected {
            try? await ws.getStates()
            try? await ws.getDeviceRegistry()
            try? await ws.getAreaRegistry()
            try? await ws.getEntityRegistry()
        } else if let rest = restClient {
            // Fallback REST fetch
            if let states = try? await rest.getAllStates() {
                didReceiveAllStates(states)
            }
        }
    }

    func rename(accessory accessoryID: AccessoryID, to newName: String) async throws {
        // HA doesn't support renaming entities via API in a simple way;
        // the user should rename in the HA UI. We could use the entity
        // registry update, but that's an advanced operation.
        throw ProviderError.unsupportedCommand
    }

    // Rooms are managed in HA's area registry — CRUD via WebSocket
    // would be possible but is out of scope for v1. Users manage areas
    // in the HA web UI.

    /// Disconnect and clean up.
    func disconnect() {
        Task {
            await wsClient?.disconnect()
        }
        pingTask?.cancel()
        pingTask = nil
        wsClient = nil
        restClient = nil
        entityStates.removeAll()
        deviceRegistry.removeAll()
        entityRegistry.removeAll()
        areaRegistry.removeAll()
        homes = []
        rooms = []
        accessories = []
        scenes = []
        authorizationState = .notDetermined
        isConnected = false
        haVersion = nil
        lastError = nil
        lastRefreshed = nil
        connectedAt = nil
        lastStateUpdateAt = nil
    }

    // MARK: - HomeAssistantWebSocketDelegate

    nonisolated func didConnect(version: String) {
        Task { @MainActor in
            self.haVersion = version
            self.isConnected = true
            self.connectedAt = Date()
            self.authorizationState = .authorized
            self.lastError = nil
            self.startPingTimer()
        }
    }

    nonisolated func didDisconnect(error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.connectedAt = nil
            self.pingTask?.cancel()
            if let error {
                self.lastError = error.localizedDescription
                if (error as NSError).code == 401 {
                    self.authorizationState = .denied
                } else {
                    self.authorizationState = .unavailable(reason: error.localizedDescription)
                }
            }

            // Auto-reconnect after 5 seconds if we have credentials
            if self.tokenStore.hasToken(for: .homeAssistantToken) {
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    if !self.isConnected {
                        await self.start()
                    }
                }
            }
        }
    }

    nonisolated func didReceiveStateChange(entityID: String, newState: HAEntityState) {
        Task { @MainActor in
            self.entityStates[entityID] = newState
            self.lastStateUpdateAt = Date()
            self.rebuildAccessory(for: entityID)
        }
    }

    nonisolated func didReceiveAllStates(_ states: [HAEntityState]) {
        Task { @MainActor in
            // Build the entity state cache
            self.entityStates.removeAll(keepingCapacity: true)
            for state in states {
                self.entityStates[state.entityID] = state
            }
            self.lastStateUpdateAt = Date()

            // Cancel any stale pending rebuild (e.g. from a rapid
            // reconnect) to avoid overlapping rebuilds and UI flicker.
            self.pendingRebuildTask?.cancel()
            self.pendingRebuildTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await self.rebuildAll()
            }
        }
    }

    // MARK: - Rebuild from HA state

    /// Full rebuild of accessories, rooms, and scenes from cached state.
    private func rebuildAll() async {
        // Fetch registry data from WebSocket client
        if let ws = wsClient {
            let devices = await ws.getDevices()
            let areas = await ws.getAreas()
            let entityEntries = await ws.getEntityRegistryEntries()

            deviceRegistry = Dictionary(
                uniqueKeysWithValues: devices.map { ($0.id, $0) }
            )
            areaRegistry = Dictionary(
                uniqueKeysWithValues: areas.map { ($0.id, $0) }
            )
            entityRegistry = Dictionary(
                uniqueKeysWithValues: entityEntries.map { ($0.entityID, $0) }
            )
        }

        rebuildRooms()
        rebuildAccessories()
        rebuildScenes()
        rebuildAutomations()

        lastRefreshed = Date()
        isRefreshing = false
    }

    private func rebuildRooms() {
        rooms = areaRegistry.values.map { area in
            Room(
                id: area.id,
                name: area.name,
                homeID: "ha.home",
                provider: .homeAssistant
            )
        }.sorted { $0.name < $1.name }
    }

    private func rebuildAccessories() {
        // Group entities by device_id so we can merge multiple entities
        // belonging to the same physical device into one Accessory.
        var deviceEntities: [String: [HAEntityState]] = [:]
        var standaloneEntities: [HAEntityState] = []

        for (entityID, entity) in entityStates {
            // Skip unsupported domains
            guard Self.supportedDomains.contains(entity.domain) else { continue }

            // Skip disabled/hidden entities
            if let reg = entityRegistry[entityID] {
                if reg.disabledBy != nil || reg.hiddenBy != nil { continue }
                // Skip diagnostic/config entities
                if let cat = reg.entityCategory, cat != "" { continue }
            }

            // Filter sensors to useful device classes only
            if entity.domain == "sensor" || entity.domain == "binary_sensor" {
                guard let dc = entity.attributes.deviceClass,
                      Self.includedSensorClasses.contains(dc) else { continue }
            }

            // Group by device ID if available
            if let regEntry = entityRegistry[entityID], let deviceID = regEntry.deviceID {
                deviceEntities[deviceID, default: []].append(entity)
            } else {
                standaloneEntities.append(entity)
            }
        }

        var newAccessories: [Accessory] = []

        // Build accessories from device-grouped entities
        for (deviceID, entities) in deviceEntities {
            guard !entities.isEmpty else { continue }
            let device = deviceRegistry[deviceID]

            // Pick the "primary" entity — prefer controllable domains
            let primary = pickPrimaryEntity(from: entities)

            // Merge capabilities from ALL entities on this device
            var caps: [Capability] = []
            for entity in entities {
                caps.append(contentsOf: HomeAssistantCapabilityMapper.capabilities(from: entity))
            }
            // Deduplicate by capability kind (keep first = primary's version)
            var seenKinds: Set<Capability.Kind> = []
            caps = caps.filter { seenKinds.insert($0.kind).inserted }

            // Fix relative cover art URLs — HA returns entity_picture as
            // "/api/media_player_proxy/..." which needs the server base URL.
            if let baseURL = restClient?.baseURL {
                caps = caps.map { cap in
                    if case .nowPlaying(var np) = cap,
                       let url = np.coverArtURL,
                       url.host == nil {
                        np.coverArtURL = baseURL.appendingPathComponent(url.path)
                        return .nowPlaying(np)
                    }
                    return cap
                }
            }

            // Determine room from device → area, or entity → area
            let areaID = device?.areaID
                ?? entities.compactMap { entityRegistry[$0.entityID]?.areaID }.first

            // Name: prefer device name, then primary entity's friendly_name
            let name = device?.name
                ?? primary.attributes.friendlyName
                ?? primary.objectID.replacingOccurrences(of: "_", with: " ").capitalized

            // Reachability: any entity that isn't "unavailable"
            let isReachable = entities.contains { $0.state != "unavailable" }

            // Speaker group membership (Sonos via HA)
            var speakerGroup: SpeakerGroupMembership?
            if primary.domain == "media_player",
               let groupMembers = primary.attributes.groupMembers,
               groupMembers.count > 1 {
                let isCoordinator = groupMembers.first == primary.entityID
                let otherNames = groupMembers
                    .filter { $0 != primary.entityID }
                    .compactMap { entityStates[$0]?.attributes.friendlyName }
                speakerGroup = SpeakerGroupMembership(
                    groupID: groupMembers.first ?? deviceID,
                    isCoordinator: isCoordinator,
                    otherMemberNames: otherNames
                )
            }

            let accessory = Accessory(
                id: AccessoryID(provider: .homeAssistant, nativeID: primary.entityID),
                name: name,
                category: HomeAssistantCapabilityMapper.category(from: primary),
                roomID: areaID,
                isReachable: isReachable,
                capabilities: caps,
                speakerGroup: speakerGroup
            )
            newAccessories.append(accessory)
        }

        // Build accessories from standalone entities (no device)
        for entity in standaloneEntities {
            let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
            guard !caps.isEmpty else { continue }

            let name = entity.attributes.friendlyName
                ?? entity.objectID.replacingOccurrences(of: "_", with: " ").capitalized
            let areaID = entityRegistry[entity.entityID]?.areaID

            let accessory = Accessory(
                id: AccessoryID(provider: .homeAssistant, nativeID: entity.entityID),
                name: name,
                category: HomeAssistantCapabilityMapper.category(from: entity),
                roomID: areaID,
                isReachable: entity.state != "unavailable",
                capabilities: caps
            )
            newAccessories.append(accessory)
        }

        accessories = newAccessories.sorted { $0.name < $1.name }

        // After the accessory list settles, probe every Frame TV for
        // its SmartThings companion entities. Cheap — at most a few
        // dictionary lookups per TV.
        rebuildFrameTVCompanions()
    }

    /// Scan television accessories for SmartThings companion entities
    /// that unlock art-mode brightness / color temperature.
    ///
    /// Primary match: any `number.` / `select.` entity in the entity
    /// registry that shares a `device_id` with the Frame's media_player
    /// and whose entity_id contains `art_brightness` /
    /// `art_color_temperature`.
    ///
    /// Fallback (for standalone entities where `device_id` is missing
    /// or not synced): derive a base name from the media_player
    /// entity_id by stripping the `media_player.` prefix and a trailing
    /// `_tv`, then look up literal `number.<base>_art_brightness` /
    /// `select.<base>_art_color_temperature` in the state cache.
    ///
    /// Populates `frameTVCompanions` from scratch every rebuild — the
    /// map is derived state, not a cache.
    private func rebuildFrameTVCompanions() {
        var companions: [String: FrameTVSmartThingsCompanion] = [:]

        for accessory in accessories
        where accessory.category == .television && accessory.id.provider == .homeAssistant {
            let mediaPlayerEntityID = accessory.id.nativeID
            var companion = FrameTVSmartThingsCompanion()

            // Primary: device_id linkage via the entity registry.
            if let primaryReg = entityRegistry[mediaPlayerEntityID],
               let deviceID = primaryReg.deviceID {
                for (otherEntityID, regEntry) in entityRegistry
                where regEntry.deviceID == deviceID && otherEntityID != mediaPlayerEntityID {
                    let lower = otherEntityID.lowercased()
                    if otherEntityID.hasPrefix("number.") && lower.contains("art_brightness") {
                        companion.artBrightnessEntityID = otherEntityID
                    } else if otherEntityID.hasPrefix("select.") && lower.contains("art_color_temperature") {
                        companion.artColorTemperatureEntityID = otherEntityID
                    }
                }
            }

            // Fallback: name-prefix lookup in the state cache.
            if companion.artBrightnessEntityID == nil ||
               companion.artColorTemperatureEntityID == nil {
                let base = baseName(fromMediaPlayerEntityID: mediaPlayerEntityID)
                if companion.artBrightnessEntityID == nil {
                    let candidate = "number.\(base)_art_brightness"
                    if entityStates[candidate] != nil {
                        companion.artBrightnessEntityID = candidate
                    }
                }
                if companion.artColorTemperatureEntityID == nil {
                    let candidate = "select.\(base)_art_color_temperature"
                    if entityStates[candidate] != nil {
                        companion.artColorTemperatureEntityID = candidate
                    }
                }
            }

            if companion.artBrightnessEntityID != nil ||
               companion.artColorTemperatureEntityID != nil {
                companions[mediaPlayerEntityID] = companion
            }
        }

        frameTVCompanions = companions
    }

    /// Derive a base entity name from a media_player entity_id.
    /// `media_player.living_room_tv` → `living_room`.
    /// `media_player.frame_tv` → `frame`.
    /// `media_player.samsung_frame` → `samsung_frame` (no `_tv` suffix).
    private func baseName(fromMediaPlayerEntityID entityID: String) -> String {
        var base = entityID
        if base.hasPrefix("media_player.") {
            base.removeFirst("media_player.".count)
        }
        if base.hasSuffix("_tv") {
            base.removeLast("_tv".count)
        }
        return base
    }

    /// Incrementally update a single accessory when its entity state changes.
    private func rebuildAccessory(for entityID: String) {
        guard let entity = entityStates[entityID],
              Self.supportedDomains.contains(entity.domain) else { return }

        // Find existing accessory with this entity as primary
        if let idx = accessories.firstIndex(where: { $0.id.nativeID == entityID }) {
            var caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
            // Fix relative cover art URLs
            if let baseURL = restClient?.baseURL {
                caps = caps.map { cap in
                    if case .nowPlaying(var np) = cap,
                       let url = np.coverArtURL,
                       url.host == nil {
                        np.coverArtURL = baseURL.appendingPathComponent(url.path)
                        return .nowPlaying(np)
                    }
                    return cap
                }
            }
            var updated = accessories[idx]
            updated.capabilities = caps
            updated.isReachable = entity.state != "unavailable"

            // Update speaker group if applicable
            if entity.domain == "media_player",
               let groupMembers = entity.attributes.groupMembers,
               groupMembers.count > 1 {
                let isCoordinator = groupMembers.first == entityID
                let otherNames = groupMembers
                    .filter { $0 != entityID }
                    .compactMap { entityStates[$0]?.attributes.friendlyName }
                updated.speakerGroup = SpeakerGroupMembership(
                    groupID: groupMembers.first ?? entityID,
                    isCoordinator: isCoordinator,
                    otherMemberNames: otherNames
                )
            } else {
                updated.speakerGroup = nil
            }

            accessories[idx] = updated
        }
        // If entity isn't a primary, a full rebuild would catch it,
        // but for performance we skip it on incremental updates.
    }

    private func rebuildScenes() {
        scenes = entityStates.values
            .filter { $0.domain == "scene" }
            .map { entity in
                HAScene(
                    entityID: entity.entityID,
                    name: entity.attributes.friendlyName ?? entity.objectID
                        .replacingOccurrences(of: "_", with: " ").capitalized,
                    lastActivated: entity.state != "unknown" ? entity.state : nil
                )
            }
            .sorted { $0.name < $1.name }
    }

    private func rebuildAutomations() {
        automations = entityStates.values
            .filter { $0.domain == "automation" }
            .map { entity in
                HAAutomation(
                    entityID: entity.entityID,
                    name: entity.attributes.friendlyName ?? entity.objectID
                        .replacingOccurrences(of: "_", with: " ").capitalized,
                    isEnabled: entity.state == "on",
                    lastTriggered: entity.attributes.raw?["last_triggered"]?.stringValue
                )
            }
            .sorted { $0.name < $1.name }
    }

    /// Trigger an automation manually via the REST API.
    func triggerAutomation(entityID: String) async throws {
        guard let rest = restClient else {
            throw ProviderError.notAuthorized
        }
        try await rest.triggerAutomation(entityID: entityID)
    }

    /// Enable or disable an automation.
    func setAutomationEnabled(entityID: String, enabled: Bool) async throws {
        guard let ws = wsClient else {
            throw ProviderError.notAuthorized
        }
        let service = enabled ? "turn_on" : "turn_off"
        try await ws.callService(
            domain: "automation",
            service: service,
            entityID: entityID
        )
    }

    /// Pick the most "important" entity from a device's entity list.
    /// Priority: light > climate > media_player > camera > fan > cover > lock > switch > sensor.
    private func pickPrimaryEntity(from entities: [HAEntityState]) -> HAEntityState {
        let priority: [String: Int] = [
            "light": 0, "climate": 1, "media_player": 2, "camera": 3,
            "fan": 4, "cover": 5, "lock": 6, "switch": 7,
            "binary_sensor": 8, "sensor": 9
        ]
        return entities.min { (priority[$0.domain] ?? 99) < (priority[$1.domain] ?? 99) } ?? entities[0]
    }

    // MARK: - Ping / keepalive

    private func startPingTimer() {
        pingTask?.cancel()
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                try? await wsClient?.ping()
            }
        }
    }

    // MARK: - Helpers

    /// Convert AnyCodableValue to Any for REST client compatibility.
    private func encodableToAny(_ value: AnyCodableValue) -> Any {
        switch value {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .null: return NSNull()
        case .array(let a): return a.map { encodableToAny($0) }
        case .dictionary(let d): return d.mapValues { encodableToAny($0) }
        }
    }

    // MARK: - Public API for scene activation

    /// Activate a HA scene. Called by the scenes UI.
    func activateScene(entityID: String) async throws {
        if let ws = wsClient, isConnected {
            try await ws.callService(
                domain: "scene",
                service: "turn_on",
                entityID: entityID
            )
        } else if let rest = restClient {
            try await rest.activateScene(entityID: entityID)
        } else {
            throw ProviderError.notAuthorized
        }
    }

    /// Get the REST client's camera proxy URL for a camera entity.
    func cameraProxyURL(entityID: String) -> URL? {
        restClient?.cameraProxyURL(entityID: entityID)
    }

    /// The base URL of the connected HA instance.
    var serverURL: URL? {
        restClient?.baseURL
    }

    // MARK: - Energy / Statistics

    /// Default statistic ID used for whole-home energy totals. HA's
    /// Energy dashboard typically exposes this as a cumulative kWh
    /// sensor. Users can override this in Settings → Energy; the
    /// chosen value is persisted under `@AppStorage("energy.entityID")`.
    static let defaultEnergyStatisticID: String = "sensor.energy_home_total"

    /// One candidate sensor that could drive the Energy dashboard.
    /// Returned by `fetchEnergySensorCandidates()`.
    struct EnergySensorCandidate: Hashable, Sendable, Identifiable {
        let entityID: String
        let friendlyName: String
        let unit: String?
        var id: String { entityID }
    }

    /// Enumerate `sensor.*` entities in the cached state that look like
    /// energy totals — either `device_class == "energy"` or
    /// `state_class == "total"` (or `"total_increasing"`) with a kWh
    /// unit. Sorted alphabetically by friendly name for stable picker
    /// presentation. Operates on the in-memory state cache, so the
    /// result is only as fresh as the last WebSocket sync.
    func fetchEnergySensorCandidates() async -> [EnergySensorCandidate] {
        var out: [EnergySensorCandidate] = []
        for (entityID, entity) in entityStates {
            guard entityID.hasPrefix("sensor.") else { continue }
            let unit = entity.attributes.unitOfMeasurement
            let deviceClass = entity.attributes.deviceClass
            let stateClass = entity.attributes.raw?["state_class"]?.stringValue

            let isEnergyClass = deviceClass == "energy"
            let isKwhTotal = (stateClass == "total" || stateClass == "total_increasing")
                && (unit?.lowercased() == "kwh" || unit?.lowercased() == "wh")

            guard isEnergyClass || isKwhTotal else { continue }

            let friendly = entity.attributes.friendlyName ?? entityID
            out.append(EnergySensorCandidate(
                entityID: entityID,
                friendlyName: friendly,
                unit: unit
            ))
        }
        return out.sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
    }

    /// Fetch recorder statistics for the default home-energy sensor
    /// over the past `lookback` window. Returns the entries for the
    /// default statistic ID (empty if HA returned nothing for it).
    ///
    /// Throws if the WebSocket isn't connected or if HA reports an error.
    func fetchEnergyStatistics(
        period: StatisticsPeriod,
        lookback: Duration,
        statisticID: String = HomeAssistantProvider.defaultEnergyStatisticID
    ) async throws -> [StatisticsEntry] {
        guard let ws = wsClient, isConnected else {
            throw ProviderError.notAuthorized
        }
        let end = Date()
        // Duration → TimeInterval. Components are (seconds, attoseconds);
        // attoseconds are negligible for an energy lookback window.
        let secs = TimeInterval(lookback.components.seconds)
        let start = end.addingTimeInterval(-secs)

        let result = try await ws.fetchStatistics(
            statisticIDs: [statisticID],
            start: start,
            end: end,
            period: period
        )
        return result[statisticID] ?? []
    }

    // MARK: - Thermostat history

    /// One point in a thermostat's history timeline. Built from HA's
    /// `/api/history/period` REST response, which returns every
    /// recorder row touching the entity over the window.
    struct HAHistoryPoint: Identifiable, Sendable {
        let id = UUID()
        /// When HA recorded this state row (`last_updated` from the API).
        let timestamp: Date
        /// The climate entity's top-level state — "heat", "cool", "off",
        /// "auto", "heat_cool". Matches the `state` column.
        let state: String
        /// Target setpoint in the server's native unit (°C on HA's
        /// default metric profile, °F if the HA install is imperial).
        /// The caller is responsible for conversion.
        let temperature: Double?
        /// Currently-measured indoor temperature.
        let currentTemperature: Double?
        /// Active HVAC action — "heating", "cooling", "idle", "off".
        /// Distinct from `state`: a thermostat in "heat" mode may be
        /// `idle` between calls for heat.
        let hvacAction: String?
        /// Preset name if set ("eco", "home", "away"…).
        let presetMode: String?
    }

    /// Fetch recorder history for a single thermostat entity over the
    /// last `hoursBack` hours. Uses the REST `/api/history/period`
    /// endpoint — cheaper than a WebSocket one-shot for a view that
    /// opens on demand, and the WebSocket client doesn't currently
    /// expose a raw history command. Points are returned in
    /// chronological ascending order; de-duplication of unchanged
    /// points is the caller's responsibility.
    func fetchThermostatHistory(
        entityID: String,
        hoursBack: Int = 24
    ) async throws -> [HAHistoryPoint] {
        guard let rest = restClient,
              let token = tokenStore.token(for: .homeAssistantToken) else {
            throw ProviderError.notAuthorized
        }

        let end = Date()
        let start = end.addingTimeInterval(TimeInterval(-hoursBack * 3600))

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startStr = iso.string(from: start)
        let endStr = iso.string(from: end)

        // Build: /api/history/period/<start>?filter_entity_id=<entity>&end_time=<end>&minimal_response=false
        let encodedStart = startStr.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? startStr
        let path = "api/history/period/\(encodedStart)"
        guard var components = URLComponents(
            url: rest.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw ProviderError.notAuthorized
        }
        components.queryItems = [
            URLQueryItem(name: "filter_entity_id", value: entityID),
            URLQueryItem(name: "end_time", value: endStr),
            URLQueryItem(name: "minimal_response", value: "false"),
            URLQueryItem(name: "no_attributes", value: "false")
        ]
        guard let url = components.url else {
            throw ProviderError.notAuthorized
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ProviderError.notAuthorized
        }

        // HA returns a 2D array: [[ state_row, state_row, ... ]] — one
        // inner array per requested entity. We asked for exactly one.
        // State rows are objects whose shape matches HAEntityState
        // minimally — but many fields (like `context`) are absent. Use
        // JSONSerialization + manual decoding rather than HAEntityState
        // to keep the parse tolerant of historical-row quirks.
        guard let root = try JSONSerialization.jsonObject(with: data) as? [[[String: Any]]],
              let rows = root.first else {
            return []
        }

        let isoParsers: [ISO8601DateFormatter] = {
            let withFrac = ISO8601DateFormatter()
            withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let noFrac = ISO8601DateFormatter()
            noFrac.formatOptions = [.withInternetDateTime]
            return [withFrac, noFrac]
        }()

        func parseDate(_ s: String) -> Date? {
            for f in isoParsers {
                if let d = f.date(from: s) { return d }
            }
            return nil
        }

        var points: [HAHistoryPoint] = []
        points.reserveCapacity(rows.count)

        for row in rows {
            guard let stateStr = row["state"] as? String else { continue }
            let tsString = (row["last_updated"] as? String)
                ?? (row["last_changed"] as? String)
            guard let tsString, let timestamp = parseDate(tsString) else { continue }

            let attrs = row["attributes"] as? [String: Any] ?? [:]
            let temperature = attrs["temperature"] as? Double
                ?? (attrs["temperature"] as? Int).map(Double.init)
            let currentTemperature = attrs["current_temperature"] as? Double
                ?? (attrs["current_temperature"] as? Int).map(Double.init)
            let hvacAction = attrs["hvac_action"] as? String
            let presetMode = attrs["preset_mode"] as? String

            points.append(HAHistoryPoint(
                timestamp: timestamp,
                state: stateStr,
                temperature: temperature,
                currentTemperature: currentTemperature,
                hvacAction: hvacAction,
                presetMode: presetMode
            ))
        }

        points.sort { $0.timestamp < $1.timestamp }
        return points
    }

    // MARK: - Diagnostics surface

    /// Read-only snapshot of integration health. Derived each access
    /// from cached registries so the diagnostics screen always sees
    /// fresh numbers without holding a reference to internal storage.
    /// Cheap — these maps are already in memory.
    struct DiagnosticsSnapshot: Sendable {
        var entityCount: Int
        var entitiesByDomain: [(domain: String, count: Int)]
        var deviceRegistryCount: Int
        var entityRegistryCount: Int
        var areaRegistryCount: Int
        var unclassifiedAccessories: [(name: String, entityID: String)]
    }

    /// Build a diagnostics snapshot from cached state. Runs on the main
    /// actor in O(n) over entities; n is at most a few thousand and the
    /// screen only reads this on demand / refresh, so no caching needed.
    func diagnosticsSnapshot() -> DiagnosticsSnapshot {
        var counts: [String: Int] = [:]
        for (_, entity) in entityStates {
            counts[entity.domain, default: 0] += 1
        }
        let sorted = counts
            .map { (domain: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        let unclassified = accessories
            .filter { $0.category == .other }
            .map { (name: $0.name, entityID: $0.id.nativeID) }
            .sorted { $0.name < $1.name }

        return DiagnosticsSnapshot(
            entityCount: entityStates.count,
            entitiesByDomain: sorted,
            deviceRegistryCount: deviceRegistry.count,
            entityRegistryCount: entityRegistry.count,
            areaRegistryCount: areaRegistry.count,
            unclassifiedAccessories: unclassified
        )
    }
}

// MARK: - Connection test (setup screen)

/// Result of a pre-save connection test from HomeAssistantSetupView.
/// Drives the inline status UI: green check on success, red line with a
/// specific message on failure. Kept outside the @MainActor class so
/// the setup view can refer to it without actor hops.
struct HAConnectionTestResult: Sendable {
    enum Status: Sendable {
        case success
        case authFailed
        case unreachable
        case invalidURL
    }

    let status: Status
    let version: String?
    let message: String
}

extension HomeAssistantProvider {
    /// Verify an HA URL + token before the user commits to saving.
    /// Normalizes the URL (default scheme http, strip trailing slash)
    /// and hits `/api/` with a 5-second timeout. 200 → success, 401 →
    /// authFailed, transport failure → unreachable.
    nonisolated static func testConnection(
        urlString: String,
        token: String
    ) async -> HAConnectionTestResult {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return HAConnectionTestResult(status: .invalidURL, version: nil,
                                          message: "Enter a URL for your Home Assistant server.")
        }
        if !normalized.lowercased().hasPrefix("http://"),
           !normalized.lowercased().hasPrefix("https://") {
            normalized = "http://\(normalized)"
        }
        while normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        guard let url = URL(string: normalized + "/api/"),
              let host = url.host, !host.isEmpty else {
            return HAConnectionTestResult(status: .invalidURL, version: nil,
                                          message: "That URL doesn't look right. Example: http://192.168.1.100:8123")
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            switch status {
            case 200:
                // Response shape: {"message": "API running.", "version": "2024.12.0"}
                struct Ping: Decodable { let version: String? }
                let version = (try? JSONDecoder().decode(Ping.self, from: data))?.version
                if let version {
                    return HAConnectionTestResult(
                        status: .success, version: version,
                        message: "Connected to Home Assistant \(version)"
                    )
                }
                return HAConnectionTestResult(
                    status: .success, version: nil,
                    message: "Connected to Home Assistant"
                )
            case 401, 403:
                return HAConnectionTestResult(
                    status: .authFailed, version: nil,
                    message: "Server reached, but token rejected."
                )
            default:
                return HAConnectionTestResult(
                    status: .unreachable, version: nil,
                    message: "Server responded with HTTP \(status)."
                )
            }
        } catch {
            return HAConnectionTestResult(
                status: .unreachable, version: nil,
                message: "Can't reach server at \(normalized)."
            )
        }
    }
}
