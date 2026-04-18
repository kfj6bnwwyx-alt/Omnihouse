//
//  AccessoryProvider.swift
//  house connect
//
//  The contract every ecosystem (HomeKit, SmartThings, Nest, ...) must fulfill.
//  Implementations are expected to be @Observable classes so SwiftUI views can
//  observe `accessories` / `rooms` / `homes` directly.
//

import Foundation

@MainActor
protocol AccessoryProvider: AnyObject {
    var id: ProviderID { get }
    var displayName: String { get }

    // State snapshot — observable on @Observable conformers.
    var homes: [Home] { get }
    var rooms: [Room] { get }
    var accessories: [Accessory] { get }

    var authorizationState: ProviderAuthorizationState { get }

    /// Initialize, request permissions, fetch initial state.
    /// Must be idempotent — safe to call on every app launch / view appear.
    func start() async

    /// Send a command to a specific accessory.
    /// Callers guarantee `accessoryID.provider == self.id`.
    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws

    /// Re-poll whatever needs polling. SmartThings re-fetches device
    /// lists + statuses, Sonos restarts Bonjour and re-reads transport
    /// state, HomeKit re-snapshots from its local HMHomeManager. The
    /// default implementation does nothing — push-driven providers
    /// (or providers without a manual refresh concept) inherit it.
    ///
    /// Hoisted onto the protocol in 2026-04-11 so generic callers
    /// (ProviderRegistry, pull-to-refresh, chooser sheets) can `await
    /// provider.refresh()` without `as? SpecificProvider` casts.
    func refresh() async

    /// Rename an accessory. Providers that don't support renaming should
    /// inherit the default implementation that throws `.unsupportedCommand`.
    func rename(accessory accessoryID: AccessoryID, to newName: String) async throws

    // MARK: - Rooms CRUD (all optional — default-throw implementations below)

    /// Create a new room in the given home. Returns the created room so the
    /// caller can show it immediately without waiting for a full refresh.
    /// Providers that don't support room creation throw `.unsupportedCommand`.
    func createRoom(named name: String, inHomeWithID homeID: String) async throws -> Room

    /// Rename an existing room. `roomID` is the native ID within this provider.
    func renameRoom(roomID: String, to newName: String) async throws

    /// Delete a room. Providers may require the room be empty first and
    /// throw `.underlying` otherwise — UI should surface the error.
    func deleteRoom(roomID: String) async throws

    /// Assign an accessory to a room within the same provider. Passing
    /// `roomID = nil` un-assigns (returns the accessory to "no room"), if
    /// the provider supports unassignment.
    func assignAccessory(_ accessoryID: AccessoryID, toRoomID roomID: String?) async throws

    /// Remove (unpair) an accessory from the provider. The accessory is
    /// deleted from the ecosystem's device list and will no longer appear
    /// in the app. HomeKit calls `HMHome.removeAccessory`; SmartThings
    /// deletes the device via the REST API; Sonos and Nest remove the
    /// local record only (the device stays on the network but disappears
    /// from our view). Providers that don't support removal inherit the
    /// default implementation that throws `.unsupportedCommand`.
    func removeAccessory(_ accessoryID: AccessoryID) async throws
}

// MARK: - Default implementations for optional capabilities
// Swift protocol requirements + default impls give us virtual dispatch:
// concrete providers can override, others fall through to these.
//
// Camera rendering is deliberately NOT on this protocol. Each ecosystem uses
// a totally different transport (HomeKit uses HMCameraView/HMCameraSource;
// SmartThings gives you an HLS URL; Nest uses WebRTC) and there's no useful
// common type to unify them. The UI's T3CameraDetailView dispatches on provider.
extension AccessoryProvider {
    func rename(accessory accessoryID: AccessoryID, to newName: String) async throws {
        throw ProviderError.unsupportedCommand
    }

    /// Default no-op refresh. HomeKit's delegate system pushes changes
    /// automatically, so its inherited default is fine unless it wants
    /// to expose a manual-refresh hook (it does — see HomeKitProvider).
    /// Poll-based providers like SmartThings/Sonos override this.
    func refresh() async { }

    func createRoom(named name: String, inHomeWithID homeID: String) async throws -> Room {
        throw ProviderError.unsupportedCommand
    }

    func renameRoom(roomID: String, to newName: String) async throws {
        throw ProviderError.unsupportedCommand
    }

    func deleteRoom(roomID: String) async throws {
        throw ProviderError.unsupportedCommand
    }

    func assignAccessory(_ accessoryID: AccessoryID, toRoomID roomID: String?) async throws {
        throw ProviderError.unsupportedCommand
    }

    func removeAccessory(_ accessoryID: AccessoryID) async throws {
        throw ProviderError.unsupportedCommand
    }
}

enum ProviderAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable(reason: String)
}

enum ProviderError: Error, LocalizedError, Sendable {
    case notAuthorized
    case accessoryNotFound
    case unsupportedCommand
    case underlying(String)

    /// Human-readable, UI-safe descriptions. Without this, Swift's
    /// synthesized description leaks the case name into the UI —
    /// e.g. `T3AccessoryDetailView`'s error alert was rendering
    /// literal text like `underlying("SmartThings error 429: Too
    /// Many Requests")` because the alert stringified the error
    /// directly. Conforming to `LocalizedError` tells the system
    /// to call `errorDescription` instead, which returns the bare
    /// message with no wrapping punctuation.
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "This ecosystem isn't connected yet. Check the Connections screen in Settings."
        case .accessoryNotFound:
            return "This device is no longer reported by its provider. Try refreshing."
        case .unsupportedCommand:
            return "That control isn't available for this device."
        case .underlying(let message):
            // `message` is already a human-readable string built
            // by the caller (usually another LocalizedError's
            // `errorDescription`). We pass it through verbatim.
            return message
        }
    }
}
