//
//  ProviderRegistry.swift
//  house connect
//
//  Fan-out facade over every registered provider. Views observe this one object
//  instead of juggling each ecosystem individually, and commands are routed here
//  by reading the `provider` namespace on the AccessoryID.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProviderRegistry {
    private(set) var providers: [any AccessoryProvider] = []

    /// Flattened accessory list across all registered providers.
    /// Because both this class and each provider are @Observable, SwiftUI
    /// tracks nested reads inside this computed property — so the UI
    /// updates when any provider's state changes.
    var allAccessories: [Accessory] {
        providers.flatMap(\.accessories)
    }

    var allRooms: [Room] {
        providers.flatMap(\.rooms)
    }

    var allHomes: [Home] {
        providers.flatMap(\.homes)
    }

    func register(_ provider: any AccessoryProvider) {
        guard !providers.contains(where: { $0.id == provider.id }) else { return }
        providers.append(provider)
    }

    func provider(for id: ProviderID) -> (any AccessoryProvider)? {
        providers.first { $0.id == id }
    }

    /// Kicks off every registered provider concurrently and returns as soon
    /// as all startup tasks have been *launched* — it does NOT wait for any
    /// provider to finish connecting. This keeps the splash gate fast: the
    /// 1.2 s minimum floor in RootContainerView fires before any slow
    /// provider (HomeAssistant WebSocket, SmartThings cloud auth, etc.) has
    /// time to block the transition. Each provider's own `start()` manages
    /// its connection lifecycle independently; views observe `authorizationState`
    /// and `isConnected` to reflect ongoing status.
    func startAll() async {
        for provider in providers {
            let p = provider
            Task { @MainActor in await p.start() }
        }
        // Yield once so each launched task gets a chance to schedule its
        // first suspension (e.g. hit the first `await` inside `start()`).
        // Without this the caller returns before any task has run at all.
        await Task.yield()
    }

    /// Re-polls every registered provider. Fired on foreground resume
    /// (see `RootContainerView.scenePhase`) so the UI re-syncs after the
    /// app has been suspended. Push-driven providers (HomeKit, and the
    /// Home Assistant WebSocket while connected) inherit the no-op
    /// default on `AccessoryProvider.refresh`; poll-based providers
    /// (SmartThings, Sonos, Nest) override it and do real work. Runs
    /// providers sequentially because most of them hit rate-limited
    /// cloud APIs — the parallelism win is small and the risk of
    /// tripping throttles is real.
    func refreshAll() async {
        for provider in providers {
            await provider.refresh()
        }
    }

    /// Routes the command to the provider indicated by the accessory's ID.
    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws {
        guard let provider = provider(for: accessoryID.provider) else {
            throw ProviderError.accessoryNotFound
        }
        try await provider.execute(command, on: accessoryID)
    }

    /// Smart-routed execute for merged (multi-provider) devices. Picks
    /// the best provider for the specific command and falls back to
    /// alternates if the preferred one fails. Used by detail views when
    /// a device is dual-homed.
    func execute(
        _ command: AccessoryCommand,
        onMerged merged: MergedDevice,
        preferredProvider: ProviderID
    ) async throws {
        let reachableIDs = Set(
            merged.allAccessoryIDs.filter { id in
                allAccessories.first(where: { $0.id == id })?.isReachable ?? false
            }
        )
        let targets = SmartCommandRouter.bestTargets(
            for: command,
            capabilityProviders: merged.capabilityProviders,
            reachableIDs: reachableIDs,
            preferredProvider: preferredProvider
        )

        guard !targets.isEmpty else {
            throw ProviderError.unsupportedCommand
        }

        var lastError: Error?
        for target in targets {
            do {
                try await execute(command, on: target)
                return // success — stop trying
            } catch {
                lastError = error
                // Try next provider
            }
        }
        // All providers failed — throw the last error
        throw lastError ?? ProviderError.unsupportedCommand
    }

    func rename(accessoryID: AccessoryID, to newName: String) async throws {
        guard let provider = provider(for: accessoryID.provider) else {
            throw ProviderError.accessoryNotFound
        }
        try await provider.rename(accessory: accessoryID, to: newName)
    }

    // MARK: - Rooms CRUD fan-out
    //
    // Rooms are provider-scoped in Phase 2b. Cross-provider "virtual rooms"
    // (one room that unifies a HomeKit and a SmartThings room) are part of
    // the capability-union story in Phase 3c and don't live here yet.

    /// Creates a room inside the provider that owns `homeID`. We infer the
    /// provider by looking up which `Home` has that ID — a home ID is
    /// globally unique across providers because each provider namespaces
    /// its own IDs.
    @discardableResult
    func createRoom(named name: String, inHomeWithID homeID: String) async throws -> Room {
        guard let home = allHomes.first(where: { $0.id == homeID }) else {
            throw ProviderError.accessoryNotFound
        }
        guard let provider = provider(for: home.provider) else {
            throw ProviderError.accessoryNotFound
        }
        return try await provider.createRoom(named: name, inHomeWithID: homeID)
    }

    func renameRoom(_ room: Room, to newName: String) async throws {
        guard let provider = provider(for: room.provider) else {
            throw ProviderError.accessoryNotFound
        }
        try await provider.renameRoom(roomID: room.id, to: newName)
    }

    func deleteRoom(_ room: Room) async throws {
        guard let provider = provider(for: room.provider) else {
            throw ProviderError.accessoryNotFound
        }
        try await provider.deleteRoom(roomID: room.id)
    }

    /// Assigns `accessoryID` to a room. The room must belong to the same
    /// provider as the accessory — rejecting cross-provider assignment here
    /// makes the current single-provider constraint explicit rather than
    /// silently failing at the provider call site.
    /// Pass `roomID = nil` to un-assign (provider permitting).
    func assignAccessory(_ accessoryID: AccessoryID, toRoomID roomID: String?) async throws {
        guard let provider = provider(for: accessoryID.provider) else {
            throw ProviderError.accessoryNotFound
        }
        if let roomID,
           let room = allRooms.first(where: { $0.id == roomID }),
           room.provider != accessoryID.provider {
            // Cross-provider assignment isn't supported until Phase 3c.
            throw ProviderError.unsupportedCommand
        }
        try await provider.assignAccessory(accessoryID, toRoomID: roomID)
    }

    /// Removes (unpairs) an accessory from its provider. After success
    /// the device disappears from `allAccessories` on the next
    /// observation cycle.
    func removeAccessory(_ accessoryID: AccessoryID) async throws {
        guard let provider = provider(for: accessoryID.provider) else {
            throw ProviderError.accessoryNotFound
        }
        try await provider.removeAccessory(accessoryID)
    }

    // MARK: - Capability check
    //
    // `AccessoryProvider`'s protocol says every provider gets rename /
    // move / remove, but the defaults all throw `.unsupportedCommand`
    // and in practice only HomeKit + SmartThings implement the full
    // trio. UI code needs to KNOW ahead of time so we can hide the
    // unsupported rows from the device-management section — catching
    // a throw after the user tapped "Rename" and showing an error
    // toast is a worse experience than never offering the row.
    //
    // The table below is the source of truth; when a new provider
    // lands (or an existing one gains a capability) this is the one
    // place to update. `DeviceManagementSupportTests` snapshots the
    // matrix so regressions show up in CI.

    enum ProviderOp {
        case renameAccessory
        case moveAccessoryToRoom
        case removeAccessory
    }

    func supports(_ op: ProviderOp, on id: AccessoryID) -> Bool {
        Self.capabilityMatrix[id.provider]?[op] ?? false
    }

    // Per-commit rollout note: `moveAccessoryToRoom` is currently
    // false for every provider because the move-to-room picker sheet
    // lands in commit 2 of this feature. Flipping HomeKit / SmartThings
    // / HA to true happens when the sheet + wiring are in.
    private static let capabilityMatrix: [ProviderID: [ProviderOp: Bool]] = [
        .homeKit: [
            .renameAccessory: true,
            .moveAccessoryToRoom: false,
            .removeAccessory: true
        ],
        .smartThings: [
            .renameAccessory: true,
            .moveAccessoryToRoom: false,
            .removeAccessory: true
        ],
        .sonos: [
            // Names managed in the Sonos app; device list is discovery-
            // driven so we can only remove the local record, which
            // reappears on the next refresh — surface remove only
            // when we're ready to manage an ignore-list, not today.
            .renameAccessory: false,
            .moveAccessoryToRoom: false,
            .removeAccessory: true
        ],
        .nest: [
            // SDM API doesn't expose name/room writes; remove is a
            // local delete (same as Sonos).
            .renameAccessory: false,
            .moveAccessoryToRoom: false,
            .removeAccessory: true
        ],
        .homeAssistant: [
            // `friendly_name` is writable via entity registry; area
            // assignment is writable via the same endpoint (added in
            // commit 3). Removal of HA entities is out of scope —
            // HA treats them as long-lived registry rows; users nuke
            // them in HA itself.
            .renameAccessory: true,
            .moveAccessoryToRoom: false,
            .removeAccessory: false
        ]
    ]
}
