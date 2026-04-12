//
//  SmartThingsProvider.swift
//  house connect
//
//  Concrete `AccessoryProvider` that speaks to Samsung SmartThings via their
//  public REST API. Uses a PAT (personal access token) for auth in Phase 2a;
//  we'll swap in OAuth later without touching the domain model.
//
//  Responsibilities:
//    - Ask KeychainTokenStore for the PAT on every API call
//    - Fetch locations / rooms / devices and hydrate `homes` / `rooms` /
//      `accessories` in terms of our unified model
//    - Pull per-device status to populate capability values
//    - Route `AccessoryCommand`s through SmartThingsCapabilityMapper
//
//  Refresh strategy for Phase 2a: pull once on start(), and expose a manual
//  `refresh()` the UI can trigger. Push updates / websocket subscriptions
//  are a Phase 3+ concern.
//

import Foundation
import Observation

@MainActor
@Observable
final class SmartThingsProvider: AccessoryProvider {
    let id: ProviderID = .smartThings
    let displayName: String = "Samsung SmartThings"

    private(set) var homes: [Home] = []
    private(set) var rooms: [Room] = []
    private(set) var accessories: [Accessory] = []
    private(set) var authorizationState: ProviderAuthorizationState = .notDetermined

    /// Last error surfaced during a refresh, so the UI can show it instead of
    /// silently failing.
    private(set) var lastError: String?

    /// Whether a refresh is currently in flight — lets the UI disable pull-
    /// to-refresh or show a spinner.
    private(set) var isRefreshing: Bool = false

    /// Timestamp of the most recent successful refresh, so the Connections
    /// screen can show "Last refreshed 2 min ago" and the user knows whether
    /// data is stale. Only set on a fully-successful API round-trip.
    private(set) var lastRefreshed: Date?

    @ObservationIgnored private let tokenStore: KeychainTokenStore
    @ObservationIgnored private let client: SmartThingsAPIClient
    @ObservationIgnored private let cache: SmartThingsAccessoryCache
    @ObservationIgnored private var didStart = false

    /// Coalesces slider-style writes (`setBrightness`, `setColorTemperature`,
    /// `setVolume`, etc.) into one network call per ~200ms. A bare slider
    /// drag in SwiftUI emits dozens of value changes per second; without
    /// debouncing, a single drag would burn right through SmartThings'
    /// ~50 writes/min rate limit and start producing 429s mid-interaction.
    /// Power, mute and transport commands bypass the debouncer (and flush
    /// any pending slider values first — see `execute(_:on:)`) so discrete
    /// taps remain snappy.
    ///
    /// Lazy because the closure captures `self`; the ivar is wired up on
    /// first access which happens inside `execute` — well after `init`.
    @ObservationIgnored private lazy var debouncer = SmartThingsWriteDebouncer(
        delay: .milliseconds(200)
    ) { [weak self] command, nativeID in
        guard let self else { return }
        do {
            try await self.performWrite(
                command,
                on: AccessoryID(provider: .smartThings, nativeID: nativeID)
            )
        } catch {
            // Debounced writes can't surface errors to the caller that
            // originally triggered them (the caller has long since
            // returned). Pin the message onto `lastError` so the Settings
            // banner at least shows it on the next render.
            self.lastError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    init(tokenStore: KeychainTokenStore, cache: SmartThingsAccessoryCache = .init()) {
        self.tokenStore = tokenStore
        self.cache = cache
        self.client = SmartThingsAPIClient(tokenProvider: { [tokenStore] in
            tokenStore.token(for: .smartThingsPAT)
        })
    }

    // MARK: - AccessoryProvider

    func start() async {
        guard !didStart else { return }
        didStart = true
        // Hydrate from disk cache so devices appear immediately as
        // "Disconnected" even before the network call completes (or
        // fails because there's no token).
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
        precondition(accessoryID.provider == .smartThings,
                     "Routing bug: non-SmartThings ID sent to SmartThingsProvider")

        // Fail fast with an actionable message instead of letting the
        // API call fail with a cryptic token/auth error.
        guard authorizationState == .authorized else {
            throw ProviderError.underlying(
                "SmartThings isn't connected. Go to Settings → Connections to add your access token."
            )
        }

        // Slider-style writes (brightness, color temp, hue, saturation,
        // target temp, volume) go through the debouncer. It returns
        // immediately — the real network call fires ~200ms after the
        // last value in a burst. If the user never lifts their finger,
        // only the final value hits the wire.
        if SmartThingsWriteDebouncer.debounceKind(for: command) != nil {
            debouncer.enqueue(command, nativeID: accessoryID.nativeID)
            return
        }

        // Discrete commands (power, mute, play/pause/next, HVAC mode)
        // flush pending slider writes for the same device FIRST. This
        // preserves the user's intent: a "drag brightness to 80% →
        // power off" sequence lands as 80%-then-off, not the reverse
        // (which would turn the light back on after the user told it
        // to turn off).
        await debouncer.flush(nativeID: accessoryID.nativeID)

        try await performWrite(command, on: accessoryID)
    }

    /// The actual network write path. Separated from `execute(_:on:)` so
    /// both the immediate-call branch and the debouncer's trailing-edge
    /// closure can share the same error mapping + optimistic refresh.
    private func performWrite(
        _ command: AccessoryCommand,
        on accessoryID: AccessoryID
    ) async throws {
        let stCommands = SmartThingsCapabilityMapper.smartThingsCommands(for: command)
        guard !stCommands.isEmpty else {
            throw ProviderError.unsupportedCommand
        }
        do {
            try await client.executeCommands(deviceId: accessoryID.nativeID, commands: stCommands)
        } catch let error as SmartThingsError {
            throw ProviderError.underlying(error.localizedDescription)
        }
        // Optimistic: re-fetch just this device's status so the UI reflects
        // the new value without waiting for a full refresh.
        await refreshDevice(nativeID: accessoryID.nativeID)
    }

    func rename(accessory accessoryID: AccessoryID, to newName: String) async throws {
        precondition(accessoryID.provider == .smartThings)
        do {
            try await client.renameDevice(deviceId: accessoryID.nativeID, newLabel: newName)
        } catch let error as SmartThingsError {
            throw ProviderError.underlying(error.localizedDescription)
        }
        // Optimistic local update so the UI reflects the new name without
        // waiting for a full refresh.
        if let index = accessories.firstIndex(where: { $0.id == accessoryID }) {
            var updated = accessories[index]
            updated.name = newName
            accessories[index] = updated
        }
    }

    // MARK: - Rooms CRUD

    func createRoom(named name: String, inHomeWithID homeID: String) async throws -> Room {
        // SmartThings calls "homes" locations; homeID == locationId.
        let stRoom: SmartThingsDTO.Room
        do {
            stRoom = try await client.createRoom(name: name, inLocation: homeID)
        } catch let error as SmartThingsError {
            throw ProviderError.underlying(error.localizedDescription)
        }
        let domainRoom = Room(
            id: stRoom.roomId,
            name: stRoom.name,
            homeID: homeID,
            provider: .smartThings
        )
        rooms.append(domainRoom)
        return domainRoom
    }

    func renameRoom(roomID: String, to newName: String) async throws {
        guard let existing = rooms.first(where: { $0.id == roomID }) else {
            throw ProviderError.accessoryNotFound
        }
        do {
            try await client.renameRoom(
                roomId: roomID,
                inLocation: existing.homeID,
                newName: newName
            )
        } catch let error as SmartThingsError {
            throw ProviderError.underlying(error.localizedDescription)
        }
        if let index = rooms.firstIndex(where: { $0.id == roomID }) {
            var updated = rooms[index]
            updated.name = newName
            rooms[index] = updated
        }
    }

    func deleteRoom(roomID: String) async throws {
        guard let existing = rooms.first(where: { $0.id == roomID }) else {
            throw ProviderError.accessoryNotFound
        }
        // SmartThings rejects deleting rooms that still hold devices. Let
        // the API error bubble up with its own message — it's clearer than
        // anything we could synthesize.
        do {
            try await client.deleteRoom(roomId: roomID, inLocation: existing.homeID)
        } catch let error as SmartThingsError {
            throw ProviderError.underlying(error.localizedDescription)
        }
        rooms.removeAll { $0.id == roomID }
    }

    func assignAccessory(_ accessoryID: AccessoryID, toRoomID roomID: String?) async throws {
        precondition(accessoryID.provider == .smartThings)
        // To move a device, SmartThings wants BOTH the target roomId and
        // the owning locationId in the same payload. Derive the location
        // from the device's current home (a SmartThings device is always
        // scoped to exactly one location).
        guard let current = accessories.first(where: { $0.id == accessoryID }) else {
            throw ProviderError.accessoryNotFound
        }
        let locationId: String
        if let roomID, let targetRoom = rooms.first(where: { $0.id == roomID }) {
            locationId = targetRoom.homeID
        } else if let existingRoom = rooms.first(where: { $0.id == current.roomID }) {
            locationId = existingRoom.homeID
        } else if let primaryHome = homes.first {
            // Accessory currently has no room assignment — fall back to
            // the first known home. SmartThings accounts almost always
            // have a single location in practice.
            locationId = primaryHome.id
        } else {
            throw ProviderError.accessoryNotFound
        }

        do {
            try await client.assignDevice(
                deviceId: accessoryID.nativeID,
                toRoomId: roomID,
                inLocation: locationId
            )
        } catch let error as SmartThingsError {
            throw ProviderError.underlying(error.localizedDescription)
        }

        if let index = accessories.firstIndex(where: { $0.id == accessoryID }) {
            var updated = accessories[index]
            updated.roomID = roomID
            accessories[index] = updated
        }
    }

    // MARK: - Remove

    /// Called when the user explicitly disconnects SmartThings (removes
    /// their token). Clears the disk cache so devices truly vanish —
    /// intentional disconnect should not leave ghost tiles.
    func disconnect() {
        cache.clear()
        homes = []
        rooms = []
        accessories = []
        authorizationState = .notDetermined
        lastError = nil
    }

    func removeAccessory(_ accessoryID: AccessoryID) async throws {
        precondition(accessoryID.provider == .smartThings)
        do {
            try await client.deleteDevice(deviceId: accessoryID.nativeID)
        } catch let error as SmartThingsError {
            throw ProviderError.underlying(error.localizedDescription)
        }
        // Optimistic local removal — the API call succeeded so we can
        // drop the accessory from our list immediately. The next full
        // refresh would also clean it up, but waiting feels sluggish.
        accessories.removeAll { $0.id == accessoryID }
    }

    // MARK: - Refresh

    /// Manually re-fetches everything from SmartThings. Called on start and
    /// whenever the user triggers a reload (e.g. after saving a new PAT).
    func refresh() async {
        guard tokenStore.hasToken(for: .smartThingsPAT) else {
            authorizationState = .notDetermined
            // Preserve existing accessories but mark all unreachable so
            // they render as "Disconnected" instead of vanishing.
            accessories = accessories.map {
                var a = $0; a.isReachable = false; return a
            }
            // If we have nothing in memory (cold start), try loading
            // from the disk cache so stale devices still appear.
            if accessories.isEmpty, let cached = cache.load() {
                homes = cached.homes
                rooms = cached.rooms
                accessories = cached.accessories.map {
                    var a = $0; a.isReachable = false; return a
                }
            }
            lastError = "SmartThings token missing — add one in Settings → Connections"
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let locations = try await client.fetchLocations()

            // Rooms: fetch per-location, flatten, map to our Room type.
            var allRooms: [Room] = []
            for location in locations {
                let stRooms = try await client.fetchRooms(locationId: location.locationId)
                allRooms.append(contentsOf: stRooms.map { r in
                    Room(
                        id: r.roomId,
                        name: r.name,
                        homeID: location.locationId,
                        provider: .smartThings
                    )
                })
            }

            // Devices: one flat list for the whole account.
            let devices = try await client.fetchDevices()

            // Status: per-device, sequentially. A smarter impl could fan out
            // with TaskGroup — deferring until we actually see a slow list.
            var built: [Accessory] = []
            for device in devices {
                let status = (try? await client.fetchDeviceStatus(deviceId: device.deviceId))
                    ?? SmartThingsDTO.DeviceStatus(components: [:])
                built.append(makeAccessory(device: device, status: status))
            }

            self.homes = locations.map { location in
                Home(
                    id: location.locationId,
                    name: location.name,
                    isPrimary: locations.first?.locationId == location.locationId,
                    provider: .smartThings
                )
            }
            self.rooms = allRooms
            self.accessories = built
            self.authorizationState = .authorized
            self.lastError = nil
            self.lastRefreshed = Date()
            // Persist to disk so devices survive app restarts when
            // the token expires or is removed later.
            cache.save(SmartThingsCacheSnapshot(
                homes: self.homes, rooms: allRooms, accessories: built
            ))
        } catch let error as SmartThingsError {
            self.lastError = error.localizedDescription
            if case .missingToken = error {
                self.authorizationState = .notDetermined
                accessories = accessories.map {
                    var a = $0; a.isReachable = false; return a
                }
            } else if case .http(let status, _) = error, status == 401 || status == 403 {
                self.authorizationState = .denied
                accessories = accessories.map {
                    var a = $0; a.isReachable = false; return a
                }
            }
            // Network errors (timeout, DNS, etc.) leave accessories
            // as-is — the last successful state is still the best guess.
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    /// Fetches fresh status for one device and replaces it in `accessories`.
    /// Used after a command so the UI reflects the new state immediately.
    private func refreshDevice(nativeID: String) async {
        do {
            let status = try await client.fetchDeviceStatus(deviceId: nativeID)
            guard let index = accessories.firstIndex(where: { $0.id.nativeID == nativeID }) else {
                return
            }
            let old = accessories[index]
            accessories[index] = Accessory(
                id: old.id,
                name: old.name,
                category: old.category,
                roomID: old.roomID,
                isReachable: old.isReachable,
                capabilities: SmartThingsCapabilityMapper.capabilities(from: status)
            )
        } catch {
            // Swallow — command already succeeded; next full refresh will sync.
        }
    }

    // MARK: - Mapping

    private func makeAccessory(
        device: SmartThingsDTO.Device,
        status: SmartThingsDTO.DeviceStatus
    ) -> Accessory {
        Accessory(
            id: AccessoryID(provider: .smartThings, nativeID: device.deviceId),
            name: device.displayName,
            category: SmartThingsCapabilityMapper.category(for: device),
            roomID: device.roomId,
            isReachable: true, // SmartThings doesn't expose a generic reachable flag
            capabilities: SmartThingsCapabilityMapper.capabilities(from: status)
        )
    }
}

// MARK: - Write Debouncer
//
// Lives in this file (rather than its own source) so we don't have to ask
// the user to add another file to the Xcode target — it's a SmartThings-
// specific implementation detail and moving it around later is cheap.

/// Coalesces rapid writes to the same `(device, capabilityKind)` slot.
///
/// Problem: SwiftUI `Slider` onChange fires on every drag tick — dozens per
/// second. Each tick becomes a `.setBrightness(...)` or `.setVolume(...)`
/// call, and SmartThings' rate limiter caps writes at ~50/min per token.
/// A one-second brightness drag will trip the limiter and start throwing
/// 429s mid-interaction, which users see as broken controls.
///
/// Fix: each slot holds exactly one pending write. Every new write for the
/// same slot replaces the previous value and restarts a 200ms timer. When
/// the timer finally fires (i.e. the user stopped dragging), the last value
/// is sent to SmartThings. Worst-case we send 5 writes/sec/slot during a
/// sustained drag instead of 60, which comfortably fits the rate budget.
///
/// Ordering guarantee: non-debounced commands (`execute`'s fallthrough path
/// in `SmartThingsProvider`) call `flush(nativeID:)` before hitting the
/// wire, so a "drag brightness → power off" sequence arrives as the user
/// intended — the brightness lands before the off, never after.
@MainActor
final class SmartThingsWriteDebouncer {
    /// The "slot" a write occupies. Two `setBrightness` calls for the same
    /// device share a key and coalesce; `setBrightness` and `setVolume`
    /// keep their own independent slots because the user might reasonably
    /// be adjusting both at once (on a soundbar with ambient lighting).
    struct Key: Hashable {
        let nativeID: String
        let kind: CommandKind
    }

    /// The stripped-down command identity the debouncer keys on.
    /// Deliberately does NOT include the associated value — we want two
    /// `.setBrightness(0.4)` and `.setBrightness(0.41)` to collapse.
    enum CommandKind: Hashable {
        case brightness
        case hue
        case saturation
        case colorTemp
        case targetTemp
        case volume
    }

    private struct Pending {
        var command: AccessoryCommand
        var task: Task<Void, Never>
    }

    private var pending: [Key: Pending] = [:]
    private let delay: Duration
    private let executor: (AccessoryCommand, String) async -> Void

    init(
        delay: Duration = .milliseconds(200),
        executor: @escaping (AccessoryCommand, String) async -> Void
    ) {
        self.delay = delay
        self.executor = executor
    }

    /// Returns the debounce slot kind for a command, or `nil` if the command
    /// should bypass the debouncer entirely (power toggles, mute, media
    /// transport, HVAC mode). The `nil` case is the contract `execute(_:on:)`
    /// uses to decide whether to enqueue or flush-then-write.
    static func debounceKind(for command: AccessoryCommand) -> CommandKind? {
        switch command {
        case .setBrightness:        return .brightness
        case .setHue:               return .hue
        case .setSaturation:        return .saturation
        case .setColorTemperature:  return .colorTemp
        case .setTargetTemperature: return .targetTemp
        case .setVolume:            return .volume
        default:
            return nil
        }
    }

    /// Enqueue a debounceable write. Replaces any pending write for the same
    /// `(nativeID, kind)` slot and restarts the 200ms timer. Returns
    /// immediately — the real network call happens on the trailing edge.
    func enqueue(_ command: AccessoryCommand, nativeID: String) {
        guard let kind = Self.debounceKind(for: command) else {
            // Should never happen in practice; the provider pre-filters.
            assertionFailure("enqueue called with non-debounceable command \(command)")
            return
        }
        let key = Key(nativeID: nativeID, kind: kind)

        // Cancel the previous timer for this slot (if any). The previous
        // command's pending value is simply dropped — that's the whole point.
        pending[key]?.task.cancel()

        let delay = self.delay
        let executor = self.executor
        let task = Task { [weak self] in
            try? await Task.sleep(for: delay)
            if Task.isCancelled { return }
            guard let self else { return }
            // Re-look up and remove atomically on the MainActor. If another
            // enqueue raced in and replaced the entry between the timer
            // firing and this block running, we'd have been cancelled — so
            // reaching here means we're still the "winner" for this slot.
            guard let entry = self.pending.removeValue(forKey: key) else { return }
            await executor(entry.command, nativeID)
        }
        pending[key] = Pending(command: command, task: task)
    }

    /// Flush any pending writes for a specific device, executing them
    /// serially and awaiting completion. Used before a non-debounced
    /// command (power, mute, transport) so the pending slider value
    /// lands before the discrete command that follows it.
    func flush(nativeID: String) async {
        let drained = pending.filter { $0.key.nativeID == nativeID }
        for (key, entry) in drained {
            entry.task.cancel()
            pending.removeValue(forKey: key)
            await executor(entry.command, nativeID)
        }
    }

    /// Drop all pending writes for a device without executing them.
    /// Currently unused but kept as the obvious "cancel on destroy" hook
    /// for when we wire this into per-device teardown.
    func cancelAll(nativeID: String) {
        let keys = pending.keys.filter { $0.nativeID == nativeID }
        for key in keys {
            pending[key]?.task.cancel()
            pending.removeValue(forKey: key)
        }
    }
}
