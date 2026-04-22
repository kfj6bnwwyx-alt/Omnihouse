//
//  ActiveDevicesFilterTests.swift
//  house connectTests
//
//  Tests for the three predicates behind T3HomeActiveDevicesSection.
//

import XCTest
@testable import house_connect

@MainActor
final class ActiveDevicesFilterTests: XCTestCase {

    // MARK: - lightsOn

    func testLightsOn_emptyRegistry() {
        XCTAssertEqual(ActiveDevicesFilter.lightsOn([]).count, 0)
    }

    func testLightsOn_includesOnReachableLights() {
        let on = makeAccessory(
            name: "Kitchen",
            category: .light,
            caps: [.power(isOn: true)],
            isReachable: true
        )
        XCTAssertEqual(ActiveDevicesFilter.lightsOn([on]).map(\.name), ["Kitchen"])
    }

    func testLightsOn_excludesOffLights() {
        let off = makeAccessory(name: "Kitchen", category: .light, caps: [.power(isOn: false)])
        XCTAssertEqual(ActiveDevicesFilter.lightsOn([off]).count, 0)
    }

    func testLightsOn_excludesUnreachable() {
        let unreachable = makeAccessory(
            name: "Kitchen", category: .light,
            caps: [.power(isOn: true)], isReachable: false
        )
        XCTAssertEqual(ActiveDevicesFilter.lightsOn([unreachable]).count, 0)
    }

    func testLightsOn_excludesNonLights() {
        let thermo = makeAccessory(
            name: "Nest",
            category: .thermostat,
            caps: [.power(isOn: true)]
        )
        XCTAssertEqual(ActiveDevicesFilter.lightsOn([thermo]).count, 0)
    }

    func testLightsOn_sortsByName() {
        let zebra = makeAccessory(name: "Zebra", category: .light, caps: [.power(isOn: true)])
        let apple = makeAccessory(name: "Apple", category: .light, caps: [.power(isOn: true)])
        let monk = makeAccessory(name: "Monk", category: .light, caps: [.power(isOn: true)])
        let result = ActiveDevicesFilter.lightsOn([zebra, apple, monk]).map(\.name)
        XCTAssertEqual(result, ["Apple", "Monk", "Zebra"])
    }

    // MARK: - nowPlaying

    func testNowPlaying_speakerWithPlaybackStatePlaying() {
        let speaker = makeAccessory(
            name: "Den",
            category: .speaker,
            caps: [.playback(state: .playing)]
        )
        XCTAssertEqual(ActiveDevicesFilter.nowPlaying([speaker]).map(\.name), ["Den"])
    }

    func testNowPlaying_speakerPaused_excluded() {
        let speaker = makeAccessory(
            name: "Den",
            category: .speaker,
            caps: [.playback(state: .paused)]
        )
        XCTAssertEqual(ActiveDevicesFilter.nowPlaying([speaker]).count, 0)
    }

    func testNowPlaying_tvFallsBackToPowerWhenNoPlaybackState() {
        // Cheaper TVs only report power, not transport. Treat isOn as playing.
        let tv = makeAccessory(
            name: "Frame",
            category: .television,
            caps: [.power(isOn: true)]
        )
        XCTAssertEqual(ActiveDevicesFilter.nowPlaying([tv]).map(\.name), ["Frame"])
    }

    func testNowPlaying_excludesNonMediaCategories() {
        let light = makeAccessory(name: "Kitchen", category: .light, caps: [.power(isOn: true)])
        XCTAssertEqual(ActiveDevicesFilter.nowPlaying([light]).count, 0)
    }

    func testNowPlaying_excludesUnreachable() {
        let speaker = makeAccessory(
            name: "Den",
            category: .speaker,
            caps: [.playback(state: .playing)],
            isReachable: false
        )
        XCTAssertEqual(ActiveDevicesFilter.nowPlaying([speaker]).count, 0)
    }

    // MARK: - climateActive

    func testClimateActive_heatMode_included() {
        let t = makeAccessory(
            name: "Hall",
            category: .thermostat,
            caps: [.hvacMode(.heat)]
        )
        XCTAssertEqual(ActiveDevicesFilter.climateActive([t]).map(\.name), ["Hall"])
    }

    func testClimateActive_offMode_excluded() {
        let t = makeAccessory(
            name: "Hall",
            category: .thermostat,
            caps: [.hvacMode(.off)]
        )
        XCTAssertEqual(ActiveDevicesFilter.climateActive([t]).count, 0)
    }

    func testClimateActive_noHvacCapability_excluded() {
        let t = makeAccessory(name: "Hall", category: .thermostat, caps: [])
        XCTAssertEqual(ActiveDevicesFilter.climateActive([t]).count, 0)
    }

    func testClimateActive_unreachable_excluded() {
        let t = makeAccessory(
            name: "Hall",
            category: .thermostat,
            caps: [.hvacMode(.heat)],
            isReachable: false
        )
        XCTAssertEqual(ActiveDevicesFilter.climateActive([t]).count, 0)
    }

    // MARK: - Mixed

    func testAllThreeFilters_pickCorrectBuckets() {
        let onLight = makeAccessory(name: "Lamp", category: .light, caps: [.power(isOn: true)])
        let offLight = makeAccessory(name: "Sconce", category: .light, caps: [.power(isOn: false)])
        let speaker = makeAccessory(name: "Den", category: .speaker, caps: [.playback(state: .playing)])
        let thermo = makeAccessory(name: "Hall", category: .thermostat, caps: [.hvacMode(.cool)])
        let lock = makeAccessory(name: "Door", category: .lock, caps: [.power(isOn: true)])

        let all = [onLight, offLight, speaker, thermo, lock]
        XCTAssertEqual(ActiveDevicesFilter.lightsOn(all).map(\.name), ["Lamp"])
        XCTAssertEqual(ActiveDevicesFilter.nowPlaying(all).map(\.name), ["Den"])
        XCTAssertEqual(ActiveDevicesFilter.climateActive(all).map(\.name), ["Hall"])
    }

    // MARK: - Helper

    private func makeAccessory(
        name: String,
        category: Accessory.Category,
        caps: [Capability] = [],
        isReachable: Bool = true
    ) -> Accessory {
        Accessory(
            id: AccessoryID(
                provider: .homeAssistant,
                nativeID: "test.\(name.lowercased())"
            ),
            name: name,
            category: category,
            roomID: nil,
            isReachable: isReachable,
            capabilities: caps
        )
    }
}
