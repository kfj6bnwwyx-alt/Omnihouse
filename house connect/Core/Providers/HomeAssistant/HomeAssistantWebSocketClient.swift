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
    /// Waits for HA's result envelope — throws `HAServiceError` when
    /// the call returns `success: false` (invalid mode, unknown
    /// entity, missing field). This is what gives commands like
    /// `climate.set_hvac_mode(hvac_mode: auto)` a visible failure
    /// path instead of silently disappearing. An 8s timeout caps the
    /// wait so a server stall can't hang the caller forever.
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

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Task {
                // Register BEFORE send so a server that replies
                // instantly still finds a waiting continuation.
                await state.registerServiceCallContinuation(id: msgID, continuation: cont)

                // Timeout watchdog — if the server never replies we
                // resume with a timeout error so the caller doesn't
                // hang. `consumeServiceCallContinuation` is idempotent
                // (removeValue), so whichever side wins is fine.
                Task { [msgID] in
                    try? await Task.sleep(for: .seconds(8))
                    if let stale = await state.consumeServiceCallContinuation(id: msgID) {
                        stale.resume(throwing: HAServiceError.timeout(
                            "\(domain).\(service) on \(entityID)"
                        ))
                    }
                }

                do {
                    try await send(command)
                } catch {
                    // Send failed before HA could reply — consume the
                    // continuation ourselves so we don't leak it.
                    if let waiter = await state.consumeServiceCallContinuation(id: msgID) {
                        waiter.resume(throwing: error)
                    }
                }
            }
        }
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

    /// Update an entity's registry row. HA's
    /// `config/entity_registry/update` message accepts any subset of
    /// editable fields — we currently use it for `name` (rename) and
    /// `area_id` (move-to-room). Routed through the same service-call
    /// continuation as real service calls, so a rejection from HA
    /// (unknown entity, invalid area) throws `HAServiceError.rejected`
    /// instead of silently succeeding.
    ///
    /// Pass nil for `areaID` to clear the area assignment (sends
    /// `"area_id": null`). Pass nil for `name` to leave the name
    /// unchanged (field is omitted from the payload).
    func updateEntityRegistry(
        entityID: String,
        name: String? = nil,
        areaID: String?? = nil
    ) async throws {
        let msgID = await state.nextID()
        // Build the payload ourselves since only a subset of the
        // typed `HAWebSocketCommand` shape is relevant here.
        var payload: [String: Any] = [
            "id": msgID,
            "type": "config/entity_registry/update",
            "entity_id": entityID
        ]
        if let name { payload["name"] = name }
        // Swift's nested optional lets us distinguish "caller didn't
        // pass areaID" (omit field) from "caller passed nil" (clear
        // the area assignment). `areaID ?? nil` collapses to the
        // inner value when present.
        if let areaUpdate = areaID {
            payload["area_id"] = areaUpdate as Any? ?? NSNull()
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Task {
                await state.registerServiceCallContinuation(id: msgID, continuation: cont)

                Task { [msgID] in
                    try? await Task.sleep(for: .seconds(8))
                    if let stale = await state.consumeServiceCallContinuation(id: msgID) {
                        stale.resume(throwing: HAServiceError.timeout(
                            "config/entity_registry/update on \(entityID)"
                        ))
                    }
                }

                do {
                    try await sendRaw(payload)
                } catch {
                    if let waiter = await state.consumeServiceCallContinuation(id: msgID) {
                        waiter.resume(throwing: error)
                    }
                }
            }
        }
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
            struct PongPeek: Decodable { let id: Int? }
            if let pong = try? JSONDecoder().decode(PongPeek.self, from: data),
               let id = pong.id {
                await state.recordPong(id: id)
            }

        default:
            break
        }
    }

    private func handleResult(_ data: Data) async {
        struct ResultPeek: Decodable {
            let id: Int
            let success: Bool
            let message: String?
            let error: ErrorBody?
            struct ErrorBody: Decodable {
                let code: String?
                let message: String?
            }
        }
        guard let peek = try? JSONDecoder().decode(ResultPeek.self, from: data) else { return }

        // Route to any pending statistics continuation first (these use the
        // raw-data path instead of the typed pending-type table).
        if let cont = await state.consumeStatisticsContinuation(id: peek.id) {
            if peek.success {
                cont.resume(returning: data)
            } else {
                let err = NSError(
                    domain: "HomeAssistant",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: peek.message ?? "statistics request failed"]
                )
                cont.resume(throwing: err)
            }
            return
        }

        // Route to any pending service-call continuation. Resumes
        // with a clear error payload when HA rejects the call, so
        // callers see real failure toasts instead of silent no-ops.
        if let cont = await state.consumeServiceCallContinuation(id: peek.id) {
            if peek.success {
                cont.resume(returning: ())
            } else {
                let msg = peek.error?.message ?? peek.message ?? "Home Assistant rejected the service call"
                cont.resume(throwing: HAServiceError.rejected(msg))
            }
            return
        }

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

    /// Fetch long-term statistics for one or more entities via the
    /// `recorder/statistics_during_period` WebSocket command. Uses a
    /// per-request continuation keyed by message ID so multiple concurrent
    /// callers don't clobber each other.
    func fetchStatistics(
        statisticIDs: [String],
        start: Date,
        end: Date,
        period: StatisticsPeriod
    ) async throws -> [String: [StatisticsEntry]] {
        let msgID = await state.nextID()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload: [String: Any] = [
            "id": msgID,
            "type": "recorder/statistics_during_period",
            "start_time": iso.string(from: start),
            "end_time": iso.string(from: end),
            "statistic_ids": statisticIDs,
            "period": period.rawValue
        ]

        let data: Data = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            Task {
                await state.registerStatisticsContinuation(id: msgID, continuation: cont)
                do {
                    try await sendRaw(payload)
                } catch {
                    if let c = await state.consumeStatisticsContinuation(id: msgID) {
                        c.resume(throwing: error)
                    }
                }
            }
        }

        struct StatsResult: Decodable {
            let result: [String: [StatisticsEntry]]
        }
        return try JSONDecoder().decode(StatsResult.self, from: data).result
    }

    /// Ping the server to keep the connection alive.
    /// Records the send timestamp so the pong handler can compute RTT.
    func ping() async throws {
        let msgID = await state.nextID()
        await state.registerPing(id: msgID)
        try? await sendRaw(["id": msgID, "type": "ping"])
    }

    /// Median WebSocket ping RTT across the last 10 samples, in milliseconds.
    /// Nil until at least one pong has been received.
    var medianPingRTTms: Double? {
        get async { await state.medianRTTMs() }
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

// MARK: - Statistics

/// Period granularity for `recorder/statistics_during_period` queries.
enum StatisticsPeriod: String, Sendable {
    case fiveMinute = "5minute"
    case hour = "hour"
    case day = "day"
    case week = "week"
    case month = "month"
}

/// One row in a statistics response. HA returns `start`/`end` as epoch
/// milliseconds; the numeric fields vary by sensor kind (cumulative
/// energy sensors populate `sum`/`state`; temperature-style sensors
/// populate `mean`/`min`/`max`).
struct StatisticsEntry: Decodable, Sendable {
    let start: Double?
    let end: Double?
    let state: Double?
    let sum: Double?
    let mean: Double?
    let min: Double?
    let max: Double?

    /// Convenience: the period's start as a Date.
    var startDate: Date? {
        start.map { Date(timeIntervalSince1970: $0 / 1000.0) }
    }

    /// Convenience: the period's end as a Date.
    var endDate: Date? {
        end.map { Date(timeIntervalSince1970: $0 / 1000.0) }
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

    /// Per-request continuations for one-shot commands that return raw
    /// data (currently: statistics_during_period). Separate from the
    /// typed `pending` table so each caller can await its own response
    /// without contending for a shared dispatch surface.
    private var statisticsContinuations: [Int: CheckedContinuation<Data, Error>] = [:]

    /// Per-request continuations for `call_service` commands. Waits
    /// for HA's `{type: result, success: ...}` envelope so mapper
    /// bugs (wrong mode name, bad field shape) surface as a thrown
    /// error instead of a silent no-op. See `callService`.
    private var serviceCallContinuations: [Int: CheckedContinuation<Void, Error>] = [:]

    /// Ping RTT tracking. Maps msgID → send timestamp so the pong handler
    /// can compute elapsed milliseconds. We only keep the last 10 samples
    /// to bound memory and keep the median stable against outliers.
    private var pingSentAt: [Int: Date] = [:]
    private var recentRTTsMs: [Double] = []
    private let maxRTTSamples = 10

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

    func registerStatisticsContinuation(id: Int, continuation: CheckedContinuation<Data, Error>) {
        statisticsContinuations[id] = continuation
    }

    func consumeStatisticsContinuation(id: Int) -> CheckedContinuation<Data, Error>? {
        statisticsContinuations.removeValue(forKey: id)
    }

    func registerServiceCallContinuation(id: Int, continuation: CheckedContinuation<Void, Error>) {
        serviceCallContinuations[id] = continuation
    }

    func consumeServiceCallContinuation(id: Int) -> CheckedContinuation<Void, Error>? {
        serviceCallContinuations.removeValue(forKey: id)
    }

    // MARK: - Ping RTT

    func registerPing(id: Int) {
        pingSentAt[id] = Date()
    }

    func recordPong(id: Int) {
        guard let sent = pingSentAt.removeValue(forKey: id) else { return }
        let rttMs = Date().timeIntervalSince(sent) * 1000.0
        recentRTTsMs.append(rttMs)
        if recentRTTsMs.count > maxRTTSamples {
            recentRTTsMs.removeFirst(recentRTTsMs.count - maxRTTSamples)
        }
    }

    func medianRTTMs() -> Double? {
        guard !recentRTTsMs.isEmpty else { return nil }
        let sorted = recentRTTsMs.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2.0
            : sorted[mid]
    }
}

// MARK: - Service-call error

/// Thrown by `callService` when HA's result envelope carries
/// `success: false` (mapper sent an invalid mode / bad field /
/// unknown entity) or when the server never replies within the
/// 8s watchdog window. Preserving a human-readable message is the
/// whole point — silent rejection is what made the Nest thermostat
/// feel broken before this layer existed.
enum HAServiceError: LocalizedError {
    case rejected(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .rejected(let msg): return msg
        case .timeout(let ctx):  return "Home Assistant didn't reply in time (\(ctx))."
        }
    }
}
