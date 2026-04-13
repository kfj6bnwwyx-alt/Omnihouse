//
//  SmartCommandRouterTests.swift
//  house connectTests
//
//  Tests for SmartCommandRouter: per-command routing for dual-homed
//  devices. Validates provider selection based on capability support,
//  reachability, and preference ordering.
//

import XCTest
@testable import house_connect

@MainActor
final class SmartCommandRouterTests: XCTestCase {

    private let hkID = AccessoryID(provider: .homeKit, nativeID: "hk-bulb")
    private let stID = AccessoryID(provider: .smartThings, nativeID: "st-bulb")
    private let sonosID = AccessoryID(provider: .sonos, nativeID: "sonos-spk")

    // MARK: - Single provider

    func testSingleProvider_ReturnsThatProvider() {
        let targets = SmartCommandRouter.bestTargets(
            for: .setPower(true),
            capabilityProviders: [.power: [hkID]],
            reachableIDs: [hkID],
            preferredProvider: .homeKit
        )
        XCTAssertEqual(targets, [hkID])
    }

    // MARK: - Dual provider, both reachable

    func testDualProvider_BothReachable_ReturnsPreferredFirst() {
        let targets = SmartCommandRouter.bestTargets(
            for: .setPower(true),
            capabilityProviders: [.power: [hkID, stID]],
            reachableIDs: [hkID, stID],
            preferredProvider: .smartThings
        )
        XCTAssertEqual(targets.first, stID)
    }

    func testDualProvider_BothReachable_HomeKitPreferred_HomeKitFirst() {
        let targets = SmartCommandRouter.bestTargets(
            for: .setBrightness(0.5),
            capabilityProviders: [.brightness: [hkID, stID]],
            reachableIDs: [hkID, stID],
            preferredProvider: .homeKit
        )
        XCTAssertEqual(targets.first, hkID)
    }

    // MARK: - Preferred offline, fallback reachable

    func testDualProvider_PreferredOffline_FallsBackToReachable() {
        let targets = SmartCommandRouter.bestTargets(
            for: .setPower(false),
            capabilityProviders: [.power: [hkID, stID]],
            reachableIDs: [stID], // HomeKit offline
            preferredProvider: .homeKit
        )
        // SmartThings should be first since it's reachable
        XCTAssertEqual(targets.first, stID)
        // HomeKit should still be in the list as fallback
        XCTAssertTrue(targets.contains(hkID))
    }

    // MARK: - Command not supported by any provider

    func testNoProvider_ReturnsEmpty() {
        let targets = SmartCommandRouter.bestTargets(
            for: .setColorTemperature(250),
            capabilityProviders: [.power: [hkID]], // has power but not colorTemp
            reachableIDs: [hkID],
            preferredProvider: .homeKit
        )
        XCTAssertTrue(targets.isEmpty)
    }

    // MARK: - Transport commands (no specific capability kind)

    func testTransportCommand_AllProvidersEligible() {
        // play/pause don't map to a specific capability kind,
        // so all providers should be candidates
        let targets = SmartCommandRouter.bestTargets(
            for: .play,
            capabilityProviders: [.power: [hkID], .volume: [sonosID]],
            reachableIDs: [hkID, sonosID],
            preferredProvider: .sonos
        )
        XCTAssertFalse(targets.isEmpty)
    }

    // MARK: - HomeKit latency tie-break

    func testTieBreak_HomeKit_BeforeSmartThings() {
        // When neither is preferred, HomeKit should win (local network)
        let targets = SmartCommandRouter.bestTargets(
            for: .setPower(true),
            capabilityProviders: [.power: [stID, hkID]],
            reachableIDs: [hkID, stID],
            preferredProvider: .nest // neither hk nor st is preferred
        )
        XCTAssertEqual(targets.first, hkID)
    }

    // MARK: - Capability kind mapping

    func testCapabilityKindMapping() {
        XCTAssertEqual(SmartCommandRouter.capabilityKind(for: .setPower(true)), .power)
        XCTAssertEqual(SmartCommandRouter.capabilityKind(for: .setBrightness(0.5)), .brightness)
        XCTAssertEqual(SmartCommandRouter.capabilityKind(for: .setHue(180)), .hue)
        XCTAssertEqual(SmartCommandRouter.capabilityKind(for: .setVolume(50)), .volume)
        XCTAssertEqual(SmartCommandRouter.capabilityKind(for: .setTargetTemperature(21)), .targetTemperature)
        XCTAssertEqual(SmartCommandRouter.capabilityKind(for: .setHVACMode(.heat)), .hvacMode)
        XCTAssertNil(SmartCommandRouter.capabilityKind(for: .play))
        XCTAssertNil(SmartCommandRouter.capabilityKind(for: .pause))
        XCTAssertNil(SmartCommandRouter.capabilityKind(for: .selfTest))
    }

    // MARK: - All unreachable

    func testAllUnreachable_StillReturnsProviders() {
        // Unreachable providers should still be returned (as fallback)
        let targets = SmartCommandRouter.bestTargets(
            for: .setPower(true),
            capabilityProviders: [.power: [hkID, stID]],
            reachableIDs: [], // both offline
            preferredProvider: .homeKit
        )
        XCTAssertEqual(targets.count, 2)
        // Preferred should still be first even when unreachable
        XCTAssertEqual(targets.first, hkID)
    }

    // MARK: - Deduplicated results

    func testMultipleCapabilities_NoDuplicateIDs() {
        // A provider supporting multiple capabilities shouldn't appear
        // multiple times in the transport command path
        let targets = SmartCommandRouter.bestTargets(
            for: .play,
            capabilityProviders: [
                .power: [hkID],
                .brightness: [hkID],
                .volume: [sonosID],
            ],
            reachableIDs: [hkID, sonosID],
            preferredProvider: .homeKit
        )
        let uniqueCount = Set(targets).count
        XCTAssertEqual(targets.count, uniqueCount, "Should not contain duplicate IDs")
    }
}
