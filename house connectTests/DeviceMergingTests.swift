//
//  DeviceMergingTests.swift
//  house connectTests
//
//  Unit tests for `DeviceMerging` (pure merge algorithm used by
//  AllDevicesView to collapse multi-provider accessories into
//  one-tile-per-physical-device entries).
//
//  Setup note:
//  -----------
//  This project doesn't have a test target yet. To run these:
//    1. In Xcode, File → New → Target → Unit Testing Bundle.
//    2. Name it "house connectTests" (matches the folder this file
//       lives in), product module "house_connectTests", host app
//       "house connect".
//    3. Add THIS file to the new target via the File Inspector
//       (or drag the folder into the project navigator).
//    4. Cmd-U to run.
//
//  No code in this file touches SwiftUI / SwiftData / network, so
//  it runs instantly without launching the host app (`Test Host: None`
//  is fine, though `@testable import house_connect` still requires
//  the host-app setting to resolve the module).
//

import XCTest
@testable import house_connect

final class DeviceMergingTests: XCTestCase {

    // MARK: - matchKey

    func testMatchKey_IsCaseInsensitive() {
        let a = makeAccessory(provider: .homeKit, name: "Kitchen Lamp", category: .light)
        let b = makeAccessory(provider: .smartThings, name: "kitchen lamp", category: .light)
        XCTAssertEqual(DeviceMerging.matchKey(for: a), DeviceMerging.matchKey(for: b))
    }

    func testMatchKey_TrimsSurroundingWhitespace() {
        let a = makeAccessory(provider: .homeKit, name: "  Kitchen Lamp  ", category: .light)
        let b = makeAccessory(provider: .smartThings, name: "Kitchen Lamp", category: .light)
        XCTAssertEqual(DeviceMerging.matchKey(for: a), DeviceMerging.matchKey(for: b))
    }

    func testMatchKey_DifferentCategories_DoNotCollide() {
        // Same name, different category — a bulb and a motion sensor
        // both called "Hallway" should NOT merge.
        let bulb = makeAccessory(provider: .homeKit, name: "Hallway", category: .light)
        let sensor = makeAccessory(provider: .homeKit, name: "Hallway", category: .sensor)
        XCTAssertNotEqual(DeviceMerging.matchKey(for: bulb), DeviceMerging.matchKey(for: sensor))
    }

    func testMatchKey_DifferentNames_DoNotCollide() {
        let a = makeAccessory(provider: .homeKit, name: "Lamp", category: .light)
        let b = makeAccessory(provider: .homeKit, name: "Floor Lamp", category: .light)
        XCTAssertNotEqual(DeviceMerging.matchKey(for: a), DeviceMerging.matchKey(for: b))
    }

    // MARK: - merge: bucketing

    func testMerge_EmptyInput_ReturnsEmpty() {
        let result = DeviceMerging.merge(
            accessories: [],
            preferenceOrder: [.homeKit, .smartThings, .sonos, .nest],
            roomNameResolver: { _ in nil }
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testMerge_SingleProviderSingleDevice_OneEntry() {
        let a = makeAccessory(provider: .homeKit, name: "Desk Lamp", category: .light)
        let result = DeviceMerging.merge(
            accessories: [a],
            preferenceOrder: [.homeKit, .smartThings, .sonos, .nest],
            roomNameResolver: { _ in "Office" }
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Desk Lamp")
        XCTAssertEqual(result[0].providers, [.homeKit])
        XCTAssertEqual(result[0].preferredID, a.id)
        XCTAssertEqual(result[0].roomName, "Office")
    }

    func testMerge_DualHomedDevice_CollapsesToOneEntry_WithBothProviders() {
        let hk = makeAccessory(provider: .homeKit, name: "Kitchen Lamp", category: .light)
        let st = makeAccessory(provider: .smartThings, name: "Kitchen Lamp", category: .light)
        let result = DeviceMerging.merge(
            accessories: [hk, st],
            preferenceOrder: [.homeKit, .smartThings, .sonos, .nest],
            roomNameResolver: { _ in nil }
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].providers, [.homeKit, .smartThings])
    }

    // MARK: - merge: preferredID respects preferenceOrder

    func testMerge_PreferredID_PicksFirstInPreferenceOrder() {
        let hk = makeAccessory(provider: .homeKit, name: "Kitchen Lamp", category: .light)
        let st = makeAccessory(provider: .smartThings, name: "Kitchen Lamp", category: .light)

        // HomeKit first → HomeKit wins.
        let hkFirst = DeviceMerging.merge(
            accessories: [st, hk], // intentionally scrambled
            preferenceOrder: [.homeKit, .smartThings, .sonos, .nest],
            roomNameResolver: { _ in nil }
        )
        XCTAssertEqual(hkFirst.first?.preferredID, hk.id)

        // SmartThings first → SmartThings wins.
        let stFirst = DeviceMerging.merge(
            accessories: [hk, st],
            preferenceOrder: [.smartThings, .homeKit, .sonos, .nest],
            roomNameResolver: { _ in nil }
        )
        XCTAssertEqual(stFirst.first?.preferredID, st.id)
    }

    func testMerge_ProviderNotInPreferenceOrder_StillAppearsInProviderList() {
        // A caller that accidentally passes a short preference order
        // shouldn't drop providers off the chip row. This is the
        // belt-and-braces pass in `merge` that appends missing
        // providers at the end.
        let hk = makeAccessory(provider: .homeKit, name: "Lamp", category: .light)
        let sonos = makeAccessory(provider: .sonos, name: "Lamp", category: .light)
        let result = DeviceMerging.merge(
            accessories: [hk, sonos],
            preferenceOrder: [.homeKit], // omits .sonos on purpose
            roomNameResolver: { _ in nil }
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].providers.contains(.sonos))
        XCTAssertTrue(result[0].providers.contains(.homeKit))
    }

    // MARK: - merge: reachability

    func testMerge_AnyReachable_KeepsTileOnline() {
        let hk = makeAccessory(provider: .homeKit, name: "Lamp", category: .light, isReachable: true)
        let st = makeAccessory(provider: .smartThings, name: "Lamp", category: .light, isReachable: false)
        let result = DeviceMerging.merge(
            accessories: [hk, st],
            preferenceOrder: [.homeKit, .smartThings, .sonos, .nest],
            roomNameResolver: { _ in nil }
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isReachable, "Any reachable instance should keep the merged tile online")
    }

    func testMerge_AllUnreachable_MarksOffline() {
        let hk = makeAccessory(provider: .homeKit, name: "Lamp", category: .light, isReachable: false)
        let st = makeAccessory(provider: .smartThings, name: "Lamp", category: .light, isReachable: false)
        let result = DeviceMerging.merge(
            accessories: [hk, st],
            preferenceOrder: [.homeKit, .smartThings, .sonos, .nest],
            roomNameResolver: { _ in nil }
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertFalse(result[0].isReachable)
    }

    // MARK: - merge: sorting

    func testMerge_Result_IsSortedByName_CaseInsensitive() {
        let a = makeAccessory(provider: .homeKit, name: "zeta Lamp", category: .light)
        let b = makeAccessory(provider: .homeKit, name: "alpha Lamp", category: .light)
        let c = makeAccessory(provider: .homeKit, name: "Beta Lamp", category: .light)
        let result = DeviceMerging.merge(
            accessories: [a, b, c],
            preferenceOrder: [.homeKit, .smartThings, .sonos, .nest],
            roomNameResolver: { _ in nil }
        )
        XCTAssertEqual(result.map(\.name), ["alpha Lamp", "Beta Lamp", "zeta Lamp"])
    }

    // MARK: - merge: room name resolution

    func testMerge_RoomNameResolver_IsCalledWithRepresentative() {
        // Verify the resolver is invoked with the chosen representative
        // accessory (the preferred provider's one), not an arbitrary
        // bucket member. A real-world bug this catches: resolver keyed
        // on `.smartThings` room IDs would otherwise sometimes receive
        // the HomeKit accessory and silently return nil.
        let hk = makeAccessory(provider: .homeKit, name: "Lamp", category: .light)
        let st = makeAccessory(provider: .smartThings, name: "Lamp", category: .light)
        var capturedProvider: ProviderID?
        _ = DeviceMerging.merge(
            accessories: [hk, st],
            preferenceOrder: [.homeKit, .smartThings, .sonos, .nest],
            roomNameResolver: { accessory in
                capturedProvider = accessory.id.provider
                return "Living Room"
            }
        )
        XCTAssertEqual(capturedProvider, .homeKit)
    }

    // MARK: - Helpers

    private func makeAccessory(
        provider: ProviderID,
        name: String,
        category: Accessory.Category,
        isReachable: Bool = true,
        roomID: String? = nil
    ) -> Accessory {
        Accessory(
            id: AccessoryID(provider: provider, nativeID: "\(provider.rawValue)-\(UUID().uuidString)"),
            name: name,
            category: category,
            roomID: roomID,
            isReachable: isReachable,
            capabilities: []
        )
    }
}
