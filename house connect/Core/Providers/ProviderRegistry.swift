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

    func startAll() async {
        for provider in providers {
            await provider.start()
        }
    }

    /// Routes the command to the provider indicated by the accessory's ID.
    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws {
        guard let provider = provider(for: accessoryID.provider) else {
            throw ProviderError.accessoryNotFound
        }
        try await provider.execute(command, on: accessoryID)
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
}
