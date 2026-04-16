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
        guard let token = tokenStore.token(for: .homeAssistantToken),
              let urlString = tokenStore.token(for: .homeAssistantURL),
              let baseURL = URL(string: urlString) else {
            authorizationState = .notDetermined
            return
        }

        let rest = HomeAssistantRESTClient(baseURL: baseURL, token: token)
        restClient = rest

        // Quick connectivity check
        let reachable = await rest.checkConnection()
        guard reachable else {
            authorizationState = .unavailable(reason: "Can't reach Home Assistant at \(urlString)")
            lastError = "Can't reach Home Assistant at \(urlString)"
            return
        }

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
    }

    // MARK: - HomeAssistantWebSocketDelegate

    nonisolated func didConnect(version: String) {
        Task { @MainActor in
            self.haVersion = version
            self.isConnected = true
            self.authorizationState = .authorized
            self.lastError = nil
            self.startPingTimer()
        }
    }

    nonisolated func didDisconnect(error: Error?) {
        Task { @MainActor in
            self.isConnected = false
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
}
