//
//  DemoNestProvider.swift
//  house connect
//
//  Placeholder Nest provider that publishes a single fake Nest Protect
//  smoke/CO alarm so the rest of the app (Devices tab, T3DeviceDetailView
//  router → T3SmokeAlarmDetailView, Live Activity simulate button) has
//  something to hang off until we wire the real Google/Nest SDM API.
//
//  Why a demo provider instead of a real one:
//  ------------------------------------------
//  The real Nest story is gated on:
//    · Device Access Console + Google OAuth setup (paid)
//    · Critical Alerts entitlement from Apple (requires app review)
//    · Smoke/CO capability cases in `Capability` (not yet modeled)
//  None of those are worth blocking the UI work on. This stub lets the
//  smoke-alarm detail screen — and its Live Activity plumbing — stay
//  reachable end-to-end in the running app without pretending we have
//  a real provider. It's intentionally advertised as "Nest (demo)" so
//  nobody mistakes it for a shipping integration.
//
//  When the real provider lands it should LAND IN ITS PLACE at the
//  same `ProviderID.nest` slot — the rest of the app is written
//  against the provider ID, not this type, so the swap is a one-line
//  change in `house_connectApp.swift`.
//
//  Phase 6 TODO when real provider replaces this:
//    · Delete this file.
//    · Add `smokeDetected(Bool)` / `coDetected(Bool)` capability cases.
//    · Replace `authorizationState = .authorized` optimism with the
//      real Google OAuth flow wired through `KeychainTokenStore`.
//

import Foundation
import Observation

@MainActor
@Observable
final class DemoNestProvider: AccessoryProvider {
    let id: ProviderID = .nest
    /// Parenthetical "(demo)" on the display label so the Settings →
    /// Connections row makes it obvious this isn't a real ecosystem
    /// integration yet. The provider-provenance badge on DeviceTile
    /// reads the short label ("NEST") so it stays clean there.
    let displayName: String = "Nest (demo)"

    // A single synthetic home + single synthetic room so the Devices
    // tile has a meaningful room subtitle ("Hallway") instead of
    // falling back to the category label. One home keeps the Rooms
    // & Zones section tidy — real Nest accounts typically have one
    // home anyway.
    private(set) var homes: [Home] = [
        Home(id: DemoNestProvider.syntheticHomeID,
             name: "Nest (demo)",
             isPrimary: false,
             provider: .nest)
    ]
    private(set) var rooms: [Room] = [
        Room(id: DemoNestProvider.syntheticRoomID,
             name: "Hallway",
             homeID: DemoNestProvider.syntheticHomeID,
             provider: .nest),
        Room(id: DemoNestProvider.syntheticLivingRoomID,
             name: "Living Room",
             homeID: DemoNestProvider.syntheticHomeID,
             provider: .nest),
        Room(id: DemoNestProvider.syntheticBedroomRoomID,
             name: "Bedroom",
             homeID: DemoNestProvider.syntheticHomeID,
             provider: .nest),
    ]
    private(set) var accessories: [Accessory] = []
    private(set) var authorizationState: ProviderAuthorizationState = .notDetermined

    /// Used as the `homeID` for the synthetic Nest home.
    nonisolated static let syntheticHomeID = "nest.demo.home"
    /// Used as the `roomID` for the synthetic Nest room.
    nonisolated static let syntheticRoomID = "nest.demo.hallway"
    /// Stable native ID for the single demo Protect so it round-trips
    /// through AccessoryID equality across refreshes.
    nonisolated static let demoProtectNativeID = "nest.demo.protect.hallway"
    /// Stable native IDs for demo thermostats. Two thermostats is
    /// typical for a Nest household (upstairs/downstairs).
    nonisolated static let syntheticLivingRoomID = "nest.demo.living-room"
    nonisolated static let demoThermostatLivingID = "nest.demo.thermostat.living"
    nonisolated static let demoThermostatBedroomID = "nest.demo.thermostat.bedroom"
    nonisolated static let syntheticBedroomRoomID = "nest.demo.bedroom"

    @ObservationIgnored private var didStart = false

    init() {}

    // MARK: - AccessoryProvider

    func start() async {
        guard !didStart else { return }
        didStart = true

        // Immediately authorized — no real OAuth to run. A real Nest
        // provider would flip to `.notDetermined` here and only land
        // on `.authorized` once Google OAuth completes.
        authorizationState = .authorized

        // Publish demo accessories: one Protect smoke alarm plus two
        // Nest Learning Thermostats (Living Room + Bedroom). This lets
        // the Devices tab, T3ThermostatView, and T3SmokeAlarmDetailView
        // all be reachable end-to-end without a real Google SDM API.
        accessories = [
            Accessory(
                id: AccessoryID(provider: .nest, nativeID: Self.demoProtectNativeID),
                name: "Nest Protect",
                category: .smokeAlarm,
                roomID: Self.syntheticRoomID,
                isReachable: true,
                capabilities: [
                    .batteryLevel(percent: 92),
                    .smokeDetected(false),
                    .coDetected(false),
                    .humidity(percent: 45),
                ]
            ),
            Accessory(
                id: AccessoryID(provider: .nest, nativeID: Self.demoThermostatLivingID),
                name: "Nest Thermostat",
                category: .thermostat,
                roomID: Self.syntheticLivingRoomID,
                isReachable: true,
                capabilities: [
                    .power(isOn: true),
                    .currentTemperature(celsius: 22.5),   // ~72.5°F
                    .targetTemperature(celsius: 21.0),     // ~70°F
                    .hvacMode(.cool),
                ]
            ),
            Accessory(
                id: AccessoryID(provider: .nest, nativeID: Self.demoThermostatBedroomID),
                name: "Nest Thermostat (Bedroom)",
                category: .thermostat,
                roomID: Self.syntheticBedroomRoomID,
                isReachable: true,
                capabilities: [
                    .power(isOn: true),
                    .currentTemperature(celsius: 20.0),   // 68°F
                    .targetTemperature(celsius: 19.5),     // ~67°F
                    .hvacMode(.heat),
                ]
            ),
        ]
    }

    // MARK: - Commands
    //
    // Demo thermostat commands mutate our local state so the UI feels
    // responsive. The Protect is still read-only (no self-test command).
    // A real provider would POST to the Google SDM API here.
    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws {
        guard let index = accessories.firstIndex(where: { $0.id == accessoryID }) else {
            throw ProviderError.accessoryNotFound
        }
        var acc = accessories[index]
        switch command {
        case .setTargetTemperature(let celsius):
            acc.capabilities.removeAll { $0.kind == .targetTemperature }
            acc.capabilities.append(.targetTemperature(celsius: celsius))
        case .setHVACMode(let mode):
            acc.capabilities.removeAll { $0.kind == .hvacMode }
            acc.capabilities.append(.hvacMode(mode))
        case .setPower(let on):
            acc.capabilities.removeAll { $0.kind == .power }
            acc.capabilities.append(.power(isOn: on))
        default:
            throw ProviderError.unsupportedCommand
        }
        accessories[index] = acc
    }

    func removeAccessory(_ accessoryID: AccessoryID) async throws {
        precondition(accessoryID.provider == .nest)
        accessories.removeAll { $0.id == accessoryID }
    }

    // Everything else — rename, room CRUD, refresh — inherits the
    // default throw / no-op impls on `AccessoryProvider`. That's
    // fine for a demo provider with hard-coded accessories.
}
