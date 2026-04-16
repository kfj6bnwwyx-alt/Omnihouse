//
//  HomeAssistantWebSocketClient.swift
//  house connect
//
//  Persistent WebSocket connection to Home Assistant. Handles:
//  - Authentication (long-lived access token)
//  - State subscription (real-time entity updates)
//  - Service calls (light.turn_on, climate.set_temperature, etc.)
//  - Device/area/entity registry queries
//
//  Uses URLSessionWebSocketTask — no third-party dependencies.
//

import Foundation

/// Delegate protocol for receiving HA WebSocket events on the main actor.
@MainActor
protocol HomeAssistantWebSocketDelegate: AnyObject {
    func didConnect(version: String)
    func didDisconnect(error: Error?)
    func didReceiveStateChange(entityID: String, newState: HAEntityState)
    func didReceiveAllStates(_ states: [HAEntityState])
}

/// Non-isolated WebSocket client. All delegate callbacks are dispatched
/// to MainActor via the delegate protocol. The client itself runs its
/// receive loop on a background task.
final class HomeAssistantWebSocketClient: Sendable {
    private let serverURL: URL
    private let token: String

    /// Nonisolated mutable state protected by an actor.
    private let state = WebSocketState()

    init(serverURL: URL, token: String) {
        // Convert http(s) to ws(s) for WebSocket
        var wsURL = serverURL
        if var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) {
            components.scheme = serverURL.scheme == "https" ? "wss" : "ws"
            components.path = "/api/websocket"
            wsURL = components.url ?? serverURL
        }
        self.serverURL = wsURL
        self.token = token
    }

    /// Connects and authenticates. Sets up the receive loop and subscribes
    /// to state_changed events. Calls delegate on success/failure.
    func connect(delegate: any HomeAssistantWebSocketDelegate) async {
        await state.setDelegate(delegate)

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: serverURL)
        await state.setTask(task)
        task.resume()

        // Start the receive loop
        Task { await receiveLoop() }
    }

    func disconnect() async {
        await state.getTask()?.cancel(with: .normalClosure, reason: nil)
        await state.setTask(nil)
    }

    /// Call a HA service (e.g. domain: "light", service: "turn_on").
    func callService(
        domain: String,
        service: String,
        data: [String: AnyCodableValue] = [:],
        entityID: String
    ) async throws {
        let msgID = await state.nextID()
        let command = HAWebSocketCommand(
            id: msgID,
            type: "call_service",
            domain: domain,
            service: service,
            serviceData: data.isEmpty ? nil : data,
            target: HAServiceTarget(entityID: [entityID])
        )
        try await send(command)
    }

    /// Request all current entity states.
    func getStates() async throws {
        let msgID = await state.nextID()
        // Register BEFORE send — if the server responds before registerPending
        // executes, handleResult would find no pending entry and drop the result.
        await state.registerPending(id: msgID, type: .getStates)
        let command = HAWebSocketCommand(id: msgID, type: "get_states")
        try await send(command)
    }

    /// Request the device registry.
    func getDeviceRegistry() async throws {
        let msgID = await state.nextID()
        await state.registerPending(id: msgID, type: .deviceRegistry)
        let command = HAWebSocketCommand(id: msgID, type: "config/device_registry/list")
        try await send(command)
    }

    /// Request the area registry.
    func getAreaRegistry() async throws {
        let msgID = await state.nextID()
        await state.registerPending(id: msgID, type: .areaRegistry)
        let command = HAWebSocketCommand(id: msgID, type: "config/area_registry/list")
        try await send(command)
    }

    /// Request the entity registry (compact display format).
    func getEntityRegistry() async throws {
        let msgID = await state.nextID()
        await state.registerPending(id: msgID, type: .entityRegistry)
        let command = HAWebSocketCommand(id: msgID, type: "config/entity_registry/list")
        try await send(command)
    }

    /// Subscribe to state_changed events for real-time updates.
    func subscribeStateChanges() async throws {
        let msgID = await state.nextID()
        let command = HAWebSocketCommand(
            id: msgID,
            type: "subscribe_events",
            eventType: "state_changed"
        )
        try await send(command)
    }

    // MARK: - Internal

    private func send(_ command: HAWebSocketCommand) async throws {
        let data = try JSONEncoder().encode(command)
        guard let string = String(data: data, encoding: .utf8) else { return }
        try await state.getTask()?.send(.string(string))
    }

    private func sendRaw(_ dict: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: dict)
        guard let string = String(data: data, encoding: .utf8) else { return }
        try await state.getTask()?.send(.string(string))
    }

    private func receiveLoop() async {
        guard let task = await state.getTask() else { return }

        while task.state == .running {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    await handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                await state.getDelegate()?.didDisconnect(error: error)
                return
            }
        }
    }

    private func handleMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }

        // First try to decode just the type field to route the message
        struct TypePeek: Decodable { let type: String }
        guard let peek = try? JSONDecoder().decode(TypePeek.self, from: data) else { return }

        switch peek.type {
        case "auth_required":
            // Send authentication
            try? await sendRaw([
                "type": "auth",
                "access_token": token
            ])

        case "auth_ok":
            struct AuthOK: Decodable {
                let haVersion: String?
                enum CodingKeys: String, CodingKey {
                    case haVersion = "ha_version"
                }
            }
            let msg = try? JSONDecoder().decode(AuthOK.self, from: data)
            await state.getDelegate()?.didConnect(version: msg?.haVersion ?? "unknown")

            // Auto-subscribe to state changes and fetch initial state
            try? await subscribeStateChanges()
            try? await getStates()
            try? await getDeviceRegistry()
            try? await getAreaRegistry()
            try? await getEntityRegistry()

        case "auth_invalid":
            struct AuthInvalid: Decodable { let message: String? }
            let msg = try? JSONDecoder().decode(AuthInvalid.self, from: data)
            let error = NSError(
                domain: "HomeAssistant",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: msg?.message ?? "Authentication failed"]
            )
            await state.getDelegate()?.didDisconnect(error: error)

        case "result":
            await handleResult(data)

        case "event":
            await handleEvent(data)

        case "pong":
            break // Heartbeat response, ignore

        default:
            break
        }
    }

    private func handleResult(_ data: Data) async {
        struct ResultPeek: Decodable {
            let id: Int
            let success: Bool
            let message: String?
        }
        guard let peek = try? JSONDecoder().decode(ResultPeek.self, from: data) else { return }
        guard peek.success else { return }

        guard let pendingType = await state.consumePending(id: peek.id) else { return }

        switch pendingType {
        case .getStates:
            struct StatesResult: Decodable {
                let result: [HAEntityState]
            }
            if let parsed = try? JSONDecoder().decode(StatesResult.self, from: data) {
                await state.getDelegate()?.didReceiveAllStates(parsed.result)
            }

        case .deviceRegistry:
            struct DevicesResult: Decodable {
                let result: [HADevice]
            }
            if let parsed = try? JSONDecoder().decode(DevicesResult.self, from: data) {
                await state.setDevices(parsed.result)
            }

        case .areaRegistry:
            struct AreasResult: Decodable {
                let result: [HAArea]
            }
            if let parsed = try? JSONDecoder().decode(AreasResult.self, from: data) {
                await state.setAreas(parsed.result)
            }

        case .entityRegistry:
            struct EntitiesResult: Decodable {
                let result: [HAEntityRegistryListEntry]
            }
            // The full entity registry list uses different keys than the display format
            if let parsed = try? JSONDecoder().decode(EntitiesResult.self, from: data) {
                await state.setEntityRegistry(parsed.result)
            }
        }
    }

    private func handleEvent(_ data: Data) async {
        struct EventMessage: Decodable {
            let event: EventPayload
            struct EventPayload: Decodable {
                let data: EventData
                struct EventData: Decodable {
                    let entityID: String
                    let newState: HAEntityState?
                    enum CodingKeys: String, CodingKey {
                        case entityID = "entity_id"
                        case newState = "new_state"
                    }
                }
            }
        }

        if let parsed = try? JSONDecoder().decode(EventMessage.self, from: data),
           let newState = parsed.event.data.newState {
            await state.getDelegate()?.didReceiveStateChange(
                entityID: parsed.event.data.entityID,
                newState: newState
            )
        }
    }

    /// Ping the server to keep the connection alive.
    func ping() async throws {
        let msgID = await state.nextID()
        try? await sendRaw(["id": msgID, "type": "ping"])
    }

    // MARK: - Registry accessors (for the provider to read after initial fetch)

    func getDevices() async -> [HADevice] {
        await state.getDevices()
    }

    func getAreas() async -> [HAArea] {
        await state.getAreas()
    }

    func getEntityRegistryEntries() async -> [HAEntityRegistryListEntry] {
        await state.getEntityRegistry()
    }
}

// MARK: - Internal mutable state actor

/// Full entity registry list entry (different from the display format).
struct HAEntityRegistryListEntry: Codable, Sendable {
    let entityID: String
    let name: String?
    let platform: String?
    let areaID: String?
    let deviceID: String?
    let disabledBy: String?
    let hiddenBy: String?
    let entityCategory: String?
    let originalName: String?

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case name
        case platform
        case areaID = "area_id"
        case deviceID = "device_id"
        case disabledBy = "disabled_by"
        case hiddenBy = "hidden_by"
        case entityCategory = "entity_category"
        case originalName = "original_name"
    }
}

private actor WebSocketState {
    private var messageID = 0
    private weak var delegate: (any HomeAssistantWebSocketDelegate)?
    private var task: URLSessionWebSocketTask?
    private var devices: [HADevice] = []
    private var areas: [HAArea] = []
    private var entityRegistry: [HAEntityRegistryListEntry] = []

    enum PendingType { case getStates, deviceRegistry, areaRegistry, entityRegistry }
    private var pending: [Int: PendingType] = [:]

    func nextID() -> Int {
        messageID += 1
        return messageID
    }

    func setDelegate(_ d: any HomeAssistantWebSocketDelegate) { delegate = d }
    func getDelegate() -> (any HomeAssistantWebSocketDelegate)? { delegate }
    func setTask(_ t: URLSessionWebSocketTask?) { task = t }
    func getTask() -> URLSessionWebSocketTask? { task }

    func registerPending(id: Int, type: PendingType) { pending[id] = type }
    func consumePending(id: Int) -> PendingType? { pending.removeValue(forKey: id) }

    func setDevices(_ d: [HADevice]) { devices = d }
    func getDevices() -> [HADevice] { devices }
    func setAreas(_ a: [HAArea]) { areas = a }
    func getAreas() -> [HAArea] { areas }
    func setEntityRegistry(_ e: [HAEntityRegistryListEntry]) { entityRegistry = e }
    func getEntityRegistry() -> [HAEntityRegistryListEntry] { entityRegistry }
}
