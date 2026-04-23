//
//  DeviceManagementSupportTests.swift
//  house connectTests
//
//  Snapshot of ProviderRegistry's capability matrix. When a new
//  provider lands or an existing one gains / loses an operation,
//  this test fails — a reminder to update the matrix rather than
//  let the UI silently throw on user taps.
//

import XCTest
@testable import house_connect

@MainActor
final class DeviceManagementSupportTests: XCTestCase {

    // MARK: - HomeKit

    func testHomeKit_renameSupported() {
        XCTAssertTrue(registry.supports(.renameAccessory, on: idFor(.homeKit)))
    }

    func testHomeKit_moveSupported() {
        XCTAssertTrue(registry.supports(.moveAccessoryToRoom, on: idFor(.homeKit)))
    }

    func testSmartThings_moveSupported() {
        XCTAssertTrue(registry.supports(.moveAccessoryToRoom, on: idFor(.smartThings)))
    }

    func testHomeKit_removeSupported() {
        XCTAssertTrue(registry.supports(.removeAccessory, on: idFor(.homeKit)))
    }

    // MARK: - SmartThings

    func testSmartThings_renameSupported() {
        XCTAssertTrue(registry.supports(.renameAccessory, on: idFor(.smartThings)))
    }

    func testSmartThings_removeSupported() {
        XCTAssertTrue(registry.supports(.removeAccessory, on: idFor(.smartThings)))
    }

    // MARK: - Sonos

    func testSonos_renameUnsupported() {
        XCTAssertFalse(registry.supports(.renameAccessory, on: idFor(.sonos)))
    }

    func testSonos_moveUnsupported() {
        XCTAssertFalse(registry.supports(.moveAccessoryToRoom, on: idFor(.sonos)))
    }

    func testSonos_removeSupported() {
        // Local-only removal; speaker reappears on next discovery.
        XCTAssertTrue(registry.supports(.removeAccessory, on: idFor(.sonos)))
    }

    // MARK: - Nest

    func testNest_renameUnsupported() {
        // SDM API doesn't expose device rename.
        XCTAssertFalse(registry.supports(.renameAccessory, on: idFor(.nest)))
    }

    func testNest_moveUnsupported() {
        XCTAssertFalse(registry.supports(.moveAccessoryToRoom, on: idFor(.nest)))
    }

    // MARK: - Home Assistant

    func testHomeAssistant_renameSupported() {
        XCTAssertTrue(registry.supports(.renameAccessory, on: idFor(.homeAssistant)))
    }

    func testHomeAssistant_moveSupported() {
        XCTAssertTrue(registry.supports(.moveAccessoryToRoom, on: idFor(.homeAssistant)))
    }

    func testHomeAssistant_removeUnsupported() {
        // HA entities are long-lived registry rows — users remove
        // them in HA itself, not from our app.
        XCTAssertFalse(registry.supports(.removeAccessory, on: idFor(.homeAssistant)))
    }

    // MARK: - Helpers

    private let registry = ProviderRegistry()

    private func idFor(_ provider: ProviderID) -> AccessoryID {
        AccessoryID(provider: provider, nativeID: "test.\(provider.rawValue)")
    }
}
