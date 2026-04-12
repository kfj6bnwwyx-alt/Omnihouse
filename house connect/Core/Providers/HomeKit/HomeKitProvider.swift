//
//  HomeKitProvider.swift
//  house connect
//
//  Wraps HMHomeManager and translates HomeKit's native types into our unified
//  Accessory/Capability vocabulary. This is the ONLY file in the app that
//  should import HomeKit — all other code works in the unified model.
//
//  Required project setup (done in Xcode, not code):
//    1. Signing & Capabilities → + Capability → HomeKit
//    2. Info tab → Privacy - HomeKit Usage Description → non-empty string
//       (Missing this string CRASHES the app on first HomeKit access.)
//

import Foundation
import HomeKit
import Observation

@MainActor
@Observable
final class HomeKitProvider: NSObject, AccessoryProvider {
    let id: ProviderID = .homeKit
    let displayName: String = "Apple Home"

    private(set) var homes: [Home] = []
    private(set) var rooms: [Room] = []
    private(set) var accessories: [Accessory] = []
    private(set) var authorizationState: ProviderAuthorizationState = .notDetermined

    /// Raw HomeKit state is kept private; only unified values leave this class.
    @ObservationIgnored private let homeManager = HMHomeManager()
    @ObservationIgnored private var didStart = false

    override init() {
        super.init()
    }

    // MARK: - AccessoryProvider

    func start() async {
        guard !didStart else { return }
        didStart = true
        homeManager.delegate = self
        // First access to HMHomeManager triggers the system permission prompt.
        refreshFromHomeManager()
        updateAuthorizationState()
    }

    /// Manual refresh. HomeKit normally pushes updates via its delegate,
    /// but we expose a refresh() so generic callers (e.g. "Refresh all
    /// providers" buttons) don't have to know we're push-driven. Calls
    /// through to the same snapshot logic the delegate uses.
    func refresh() async {
        refreshFromHomeManager()
    }

    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws {
        precondition(accessoryID.provider == .homeKit, "Routing bug: non-HomeKit ID sent to HomeKitProvider")
        guard let hmAccessory = findHMAccessory(nativeID: accessoryID.nativeID) else {
            throw ProviderError.accessoryNotFound
        }
        switch command {
        case .setPower(let on):
            try await writeCharacteristic(on: hmAccessory,
                                          type: HMCharacteristicTypePowerState,
                                          value: NSNumber(value: on))
        case .setBrightness(let v):
            let pct = Int((max(0, min(1, v)) * 100).rounded())
            try await writeCharacteristic(on: hmAccessory,
                                          type: HMCharacteristicTypeBrightness,
                                          value: NSNumber(value: pct))
        case .setHue(let deg):
            try await writeCharacteristic(on: hmAccessory,
                                          type: HMCharacteristicTypeHue,
                                          value: NSNumber(value: deg))
        case .setSaturation(let s):
            try await writeCharacteristic(on: hmAccessory,
                                          type: HMCharacteristicTypeSaturation,
                                          value: NSNumber(value: s * 100))
        case .setColorTemperature(let mireds):
            try await writeCharacteristic(on: hmAccessory,
                                          type: HMCharacteristicTypeColorTemperature,
                                          value: NSNumber(value: mireds))
        case .setTargetTemperature(let celsius):
            try await writeCharacteristic(on: hmAccessory,
                                          type: HMCharacteristicTypeTargetTemperature,
                                          value: NSNumber(value: celsius))
        case .setHVACMode(let mode):
            // HMCharacteristicTypeTargetHeatingCooling uses the same
            // 0/1/2/3 = off/heat/cool/auto enum as HomeKit exposes in
            // HMCharacteristicValueHeatingCooling*. We write raw Ints so
            // the code doesn't depend on that symbol (it's typed as an
            // NSInteger anyway).
            let raw: Int
            switch mode {
            case .off: raw = 0
            case .heat: raw = 1
            case .cool: raw = 2
            case .auto: raw = 3
            }
            try await writeCharacteristic(on: hmAccessory,
                                          type: HMCharacteristicTypeTargetHeatingCooling,
                                          value: NSNumber(value: raw))
        case .play, .pause, .stop, .next, .previous,
             .setVolume, .setGroupVolume, .setMute, .setShuffle, .setRepeatMode,
             .joinSpeakerGroup, .leaveSpeakerGroup, .selfTest:
            // HomeKit has no unified media-transport characteristics. If we
            // ever want HomeKit-side media control, the linked native
            // provider (Sonos / Samsung TV / ...) handles it directly via
            // capability-union routing (Phase 3c). Until then, reject.
            // The grouping commands are Sonos-only today and share the
            // same fate — HomeKit has no zone-group concept at all.
            throw ProviderError.unsupportedCommand
        }
    }

    // MARK: - Rename

    func rename(accessory accessoryID: AccessoryID, to newName: String) async throws {
        precondition(accessoryID.provider == .homeKit)
        guard let hmAccessory = findHMAccessory(nativeID: accessoryID.nativeID) else {
            throw ProviderError.accessoryNotFound
        }
        do {
            try await hmAccessory.updateName(newName)
        } catch {
            throw ProviderError.underlying(error.localizedDescription)
        }
        // HomeKit doesn't fire homeManagerDidUpdateHomes for rename — pull the
        // new state manually so the UI reflects it immediately.
        refreshFromHomeManager()
    }

    // MARK: - Remove (unpair)

    func removeAccessory(_ accessoryID: AccessoryID) async throws {
        precondition(accessoryID.provider == .homeKit)
        guard let hmAccessory = findHMAccessory(nativeID: accessoryID.nativeID) else {
            throw ProviderError.accessoryNotFound
        }
        guard let hmHome = findHMHomeContaining(accessory: hmAccessory) else {
            throw ProviderError.accessoryNotFound
        }
        do {
            try await hmHome.removeAccessory(hmAccessory)
        } catch {
            throw ProviderError.underlying(error.localizedDescription)
        }
        refreshFromHomeManager()
    }

    // MARK: - Rooms CRUD

    func createRoom(named name: String, inHomeWithID homeID: String) async throws -> Room {
        guard let hmHome = findHMHome(id: homeID) else {
            throw ProviderError.accessoryNotFound
        }
        let hmRoom: HMRoom
        do {
            // Objective-C method is `addRoomWithName:completionHandler:`, but
            // the HomeKit headers annotate it with `NS_SWIFT_ASYNC_NAME` so
            // the async bridge exposes it as `addRoom(named:)`. Using the
            // plain `withName:` label resolves to the sync completion-handler
            // overload and won't compile against this signature.
            hmRoom = try await hmHome.addRoom(named: name)
        } catch {
            throw ProviderError.underlying(error.localizedDescription)
        }
        // HomeKit doesn't always fire a delegate for our own mutations,
        // so pull state after every write.
        refreshFromHomeManager()
        return Room(
            id: hmRoom.uniqueIdentifier.uuidString,
            name: hmRoom.name,
            homeID: hmHome.uniqueIdentifier.uuidString,
            provider: .homeKit
        )
    }

    func renameRoom(roomID: String, to newName: String) async throws {
        guard let (_, hmRoom) = findHMRoom(id: roomID) else {
            throw ProviderError.accessoryNotFound
        }
        do {
            try await hmRoom.updateName(newName)
        } catch {
            throw ProviderError.underlying(error.localizedDescription)
        }
        refreshFromHomeManager()
    }

    func deleteRoom(roomID: String) async throws {
        guard let (hmHome, hmRoom) = findHMRoom(id: roomID) else {
            throw ProviderError.accessoryNotFound
        }
        // HomeKit's removeRoom fails if accessories still reference the
        // room. Let the error bubble up — the UI will surface a message.
        do {
            try await hmHome.removeRoom(hmRoom)
        } catch {
            throw ProviderError.underlying(error.localizedDescription)
        }
        refreshFromHomeManager()
    }

    func assignAccessory(_ accessoryID: AccessoryID, toRoomID roomID: String?) async throws {
        precondition(accessoryID.provider == .homeKit)
        guard let hmAccessory = findHMAccessory(nativeID: accessoryID.nativeID) else {
            throw ProviderError.accessoryNotFound
        }
        // HomeKit requires the room to belong to the accessory's home.
        // Find the home, then resolve either the target room or the
        // home's implicit "Default Room" when the caller passes nil.
        guard let hmHome = findHMHomeContaining(accessory: hmAccessory) else {
            throw ProviderError.accessoryNotFound
        }
        let targetRoom: HMRoom
        if let roomID {
            guard let uuid = UUID(uuidString: roomID),
                  let match = hmHome.rooms.first(where: { $0.uniqueIdentifier == uuid }) else {
                throw ProviderError.accessoryNotFound
            }
            targetRoom = match
        } else {
            // Un-assign = move back to the home's default room. HomeKit
            // doesn't expose a true "no room" state.
            targetRoom = hmHome.roomForEntireHome()
        }
        do {
            try await hmHome.assignAccessory(hmAccessory, to: targetRoom)
        } catch {
            throw ProviderError.underlying(error.localizedDescription)
        }
        refreshFromHomeManager()
    }

    // MARK: - Home / room lookups

    private func findHMHome(id: String) -> HMHome? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return homeManager.homes.first { $0.uniqueIdentifier == uuid }
    }

    private func findHMRoom(id: String) -> (HMHome, HMRoom)? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        for hmHome in homeManager.homes {
            if let hmRoom = hmHome.rooms.first(where: { $0.uniqueIdentifier == uuid }) {
                return (hmHome, hmRoom)
            }
        }
        return nil
    }

    private func findHMHomeContaining(accessory: HMAccessory) -> HMHome? {
        homeManager.homes.first { home in
            home.accessories.contains(where: { $0.uniqueIdentifier == accessory.uniqueIdentifier })
        }
    }

    // MARK: - Camera profile access (used by HomeKitCameraView)

    /// Returns the first camera profile for a HomeKit accessory, if any.
    /// Leaks a HomeKit type on purpose — only HomeKit-specific view code
    /// (HomeKitCameraView) calls this, and HMCameraView needs real HomeKit
    /// types to render. Other views should stay in the unified domain model.
    func cameraProfile(forNativeID nativeID: String) -> HMCameraProfile? {
        guard let hmAccessory = findHMAccessory(nativeID: nativeID) else { return nil }
        return hmAccessory.cameraProfiles?.first
    }

    // MARK: - Accessory setup (HomeKit-specific; not part of the protocol)

    /// Presents Apple's native HomeKit accessory setup UI. iOS 15.4+.
    /// Call from a user-initiated event (e.g. the dashboard '+' button).
    /// The system shows its own sheet — we don't render anything ourselves.
    func beginAccessorySetup(inHomeWithID homeID: String? = nil) async throws {
        let manager = HMAccessorySetupManager()
        let request = HMAccessorySetupRequest()
        // HMHomeManager.primaryHome was deprecated in iOS 16.1 — Apple
        // removed the concept of a manager-level "primary home". Apps are
        // expected to either let the user pick or default to the first
        // known home. We default to the first; multi-home support gets a
        // proper picker when/if the user asks for it.
        if let homeID,
           let uuid = UUID(uuidString: homeID),
           let home = homeManager.homes.first(where: { $0.uniqueIdentifier == uuid }) {
            request.homeUniqueIdentifier = home.uniqueIdentifier
        } else if let firstHome = homeManager.homes.first {
            request.homeUniqueIdentifier = firstHome.uniqueIdentifier
        }
        do {
            _ = try await manager.performAccessorySetup(using: request)
        } catch {
            throw ProviderError.underlying(error.localizedDescription)
        }
        // Setup delegate fires updates, but refresh defensively.
        refreshFromHomeManager()
    }

    // MARK: - Refresh / mapping

    private func refreshFromHomeManager() {
        let hmHomes = homeManager.homes

        // `primaryHome` was deprecated in iOS 16.1. For UI purposes we treat
        // the first home in HMHomeManager's list as primary — it's stable
        // across launches and matches the ordering the Home app uses.
        let primaryHomeID = hmHomes.first?.uniqueIdentifier

        self.homes = hmHomes.map { hmHome in
            Home(id: hmHome.uniqueIdentifier.uuidString,
                 name: hmHome.name,
                 isPrimary: hmHome.uniqueIdentifier == primaryHomeID,
                 provider: .homeKit)
        }

        self.rooms = hmHomes.flatMap { hmHome in
            hmHome.rooms.map { hmRoom in
                Room(id: hmRoom.uniqueIdentifier.uuidString,
                     name: hmRoom.name,
                     homeID: hmHome.uniqueIdentifier.uuidString,
                     provider: .homeKit)
            }
        }

        // First pass: map with whatever values are cached. Capabilities
        // that had nil values get default placeholders so the UI always
        // renders controls for supported characteristics.
        self.accessories = hmHomes.flatMap { hmHome in
            hmHome.accessories.map { mapAccessory($0) }
        }

        // Second pass (async): read the live characteristic values from
        // the accessories. This populates `ch.value` for any characteristics
        // that were nil (e.g. after reboot or cold-cache discovery), then
        // re-maps so the UI picks up the real state. Because the provider
        // is @Observable, the second publish triggers a SwiftUI update
        // automatically — the user sees controls appear immediately with
        // defaults, then snap to real values a moment later.
        Task {
            await readAndRefreshCharacteristicValues(hmHomes: hmHomes)
        }
    }

    /// Reads the live value of every controllable characteristic from
    /// each accessory, then re-maps the full accessory list so the
    /// published capabilities carry real data instead of defaults.
    private func readAndRefreshCharacteristicValues(hmHomes: [HMHome]) async {
        let controllableTypes: Set<String> = [
            HMCharacteristicTypePowerState,
            HMCharacteristicTypeBrightness,
            HMCharacteristicTypeHue,
            HMCharacteristicTypeSaturation,
            HMCharacteristicTypeColorTemperature,
            HMCharacteristicTypeCurrentTemperature,
            HMCharacteristicTypeTargetTemperature,
            HMCharacteristicTypeTargetHeatingCooling,
            HMCharacteristicTypeBatteryLevel,
        ]

        // Fire reads in parallel per-accessory (each readValue is one
        // HAP round-trip). We don't await each individual read — any
        // that fail (unreachable, timed-out) are silently ignored; the
        // UI keeps showing the default from the first pass.
        await withTaskGroup(of: Void.self) { group in
            for hmHome in hmHomes {
                for hmAccessory in hmHome.accessories where hmAccessory.isReachable {
                    for service in hmAccessory.services {
                        for ch in service.characteristics where controllableTypes.contains(ch.characteristicType) {
                            group.addTask {
                                try? await ch.readValue()
                            }
                        }
                    }
                }
            }
        }

        // Re-map now that ch.value is populated with fresh reads.
        self.accessories = hmHomes.flatMap { hmHome in
            hmHome.accessories.map { mapAccessory($0) }
        }
    }

    private func mapAccessory(_ hmAccessory: HMAccessory) -> Accessory {
        Accessory(
            id: AccessoryID(provider: .homeKit,
                            nativeID: hmAccessory.uniqueIdentifier.uuidString),
            name: hmAccessory.name,
            category: mapCategory(hmAccessory.category.categoryType),
            roomID: hmAccessory.room?.uniqueIdentifier.uuidString,
            isReachable: hmAccessory.isReachable,
            capabilities: extractCapabilities(from: hmAccessory)
        )
    }

    private func extractCapabilities(from hmAccessory: HMAccessory) -> [Capability] {
        var caps: [Capability] = []
        // Track which capability kinds we've already seen so we don't
        // double-append if multiple services advertise the same
        // characteristic type (rare, but possible with bridged hubs).
        var seen = Set<String>()

        for service in hmAccessory.services {
            for ch in service.characteristics {
                let type = ch.characteristicType
                guard seen.insert(type).inserted else { continue }

                switch type {
                case HMCharacteristicTypePowerState:
                    // `value` is an NSNumber bridging to Bool. When the
                    // cache is cold (just discovered, or after reboot)
                    // `value` can be nil — default to off so the toggle
                    // renders and triggers a readValue on first interact.
                    let on = numericBool(ch.value) ?? false
                    caps.append(.power(isOn: on))

                case HMCharacteristicTypeBrightness:
                    // HomeKit brightness is 0-100 Int. NSNumber may bridge
                    // as Int, Float, or Double depending on the accessory's
                    // HAP implementation. Default to 0 if value not yet
                    // cached — the user sees the slider at 0 and can drag.
                    let pct = numericDouble(ch.value) ?? 0
                    caps.append(.brightness(value: pct / 100.0))

                case HMCharacteristicTypeHue:
                    let deg = numericDouble(ch.value) ?? 0
                    caps.append(.hue(degrees: deg))

                case HMCharacteristicTypeSaturation:
                    let pct = numericDouble(ch.value) ?? 0
                    caps.append(.saturation(value: pct / 100.0))

                case HMCharacteristicTypeColorTemperature:
                    // HAP color-temperature is in mireds (140-500 typical).
                    let mireds = numericInt(ch.value) ?? 250
                    caps.append(.colorTemperature(mireds: mireds))

                case HMCharacteristicTypeCurrentTemperature:
                    let c = numericDouble(ch.value) ?? 0
                    caps.append(.currentTemperature(celsius: c))

                case HMCharacteristicTypeTargetTemperature:
                    let c = numericDouble(ch.value) ?? 20
                    caps.append(.targetTemperature(celsius: c))

                case HMCharacteristicTypeTargetHeatingCooling:
                    // 0 = off, 1 = heat, 2 = cool, 3 = auto (per Apple's
                    // HMCharacteristicValueHeatingCoolingOff / Heat / Cool /
                    // Auto constants). We keep the raw Int comparison so we
                    // don't depend on those symbols being importable here.
                    let raw = numericInt(ch.value) ?? 0
                    switch raw {
                    case 0: caps.append(.hvacMode(.off))
                    case 1: caps.append(.hvacMode(.heat))
                    case 2: caps.append(.hvacMode(.cool))
                    case 3: caps.append(.hvacMode(.auto))
                    default: caps.append(.hvacMode(.off))
                    }

                case HMCharacteristicTypeBatteryLevel:
                    let p = numericInt(ch.value) ?? 0
                    caps.append(.batteryLevel(percent: p))

                default:
                    break
                }
            }
        }
        return caps
    }

    // MARK: - NSNumber coercion helpers
    //
    // HomeKit characteristics are Obj-C typed — values arrive as `Any?`
    // wrapping an `NSNumber`. Depending on the HAP accessory implementation
    // the underlying objCType can be BOOL, int, float, or double for the
    // same characteristic type. These helpers paper over the variance so
    // `extractCapabilities` doesn't need per-type casting gymnastics.

    private func numericBool(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        return nil
    }

    private func numericDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        return nil
    }

    private func numericInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }

    private func mapCategory(_ type: String) -> Accessory.Category {
        switch type {
        case HMAccessoryCategoryTypeLightbulb: .light
        case HMAccessoryCategoryTypeOutlet: .outlet
        case HMAccessoryCategoryTypeSwitch: .switch
        case HMAccessoryCategoryTypeThermostat: .thermostat
        case HMAccessoryCategoryTypeDoorLock: .lock
        case HMAccessoryCategoryTypeSensor: .sensor
        case HMAccessoryCategoryTypeIPCamera, HMAccessoryCategoryTypeVideoDoorbell: .camera
        case HMAccessoryCategoryTypeFan: .fan
        case HMAccessoryCategoryTypeWindowCovering: .blinds
        case HMAccessoryCategoryTypeTelevision: .television
        default: .other
        }
    }

    private func findHMAccessory(nativeID: String) -> HMAccessory? {
        for hmHome in homeManager.homes {
            if let acc = hmHome.accessories.first(where: { $0.uniqueIdentifier.uuidString == nativeID }) {
                return acc
            }
        }
        return nil
    }

    private func writeCharacteristic(on hmAccessory: HMAccessory, type: String, value: Any) async throws {
        for service in hmAccessory.services {
            if let ch = service.characteristics.first(where: { $0.characteristicType == type }) {
                do {
                    try await ch.writeValue(value)
                    return
                } catch {
                    throw ProviderError.underlying(error.localizedDescription)
                }
            }
        }
        throw ProviderError.unsupportedCommand
    }

    private func updateAuthorizationState() {
        let status = homeManager.authorizationStatus
        if status.contains(.authorized) {
            authorizationState = .authorized
        } else if status.contains(.restricted) {
            authorizationState = .restricted
        } else if status.contains(.determined) {
            // Determined but not authorized → user denied.
            authorizationState = .denied
        } else {
            authorizationState = .notDetermined
        }
    }
}

// MARK: - HMHomeManagerDelegate

extension HomeKitProvider: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.refreshFromHomeManager()
            self.updateAuthorizationState()
        }
    }

    nonisolated func homeManagerDidUpdatePrimaryHome(_ manager: HMHomeManager) {
        Task { @MainActor in self.refreshFromHomeManager() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        Task { @MainActor in self.refreshFromHomeManager() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        Task { @MainActor in self.refreshFromHomeManager() }
    }
}
