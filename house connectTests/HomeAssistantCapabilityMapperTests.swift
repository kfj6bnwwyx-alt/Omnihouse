//
//  HomeAssistantCapabilityMapperTests.swift
//  house connectTests
//
//  Tests for the HA entity → unified Capability mapping layer.
//

import XCTest
@testable import house_connect

@MainActor
final class HomeAssistantCapabilityMapperTests: XCTestCase {

    // MARK: - Category inference

    func testCategory_Light() {
        let entity = makeEntity(domain: "light")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .light)
    }

    func testCategory_Climate() {
        let entity = makeEntity(domain: "climate")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .thermostat)
    }

    func testCategory_MediaPlayer() {
        let entity = makeEntity(domain: "media_player")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .speaker)
    }

    func testCategory_Camera() {
        let entity = makeEntity(domain: "camera")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .camera)
    }

    func testCategory_Lock() {
        let entity = makeEntity(domain: "lock")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .lock)
    }

    func testCategory_Fan() {
        let entity = makeEntity(domain: "fan")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .fan)
    }

    func testCategory_Cover() {
        let entity = makeEntity(domain: "cover")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .blinds)
    }

    func testCategory_Switch() {
        let entity = makeEntity(domain: "switch")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .switch)
    }

    func testCategory_Sensor() {
        let entity = makeEntity(domain: "sensor")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .sensor)
    }

    func testCategory_BinarySensor() {
        let entity = makeEntity(domain: "binary_sensor")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .sensor)
    }

    func testCategory_Unknown() {
        let entity = makeEntity(domain: "vacuum")
        XCTAssertEqual(HomeAssistantCapabilityMapper.category(from: entity), .other)
    }

    // MARK: - Light capabilities

    func testLight_On_HasPower() {
        let entity = makeEntity(domain: "light", state: "on")
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.power(isOn: true)))
    }

    func testLight_Off_HasPower() {
        let entity = makeEntity(domain: "light", state: "off")
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.power(isOn: false)))
    }

    func testLight_Brightness_MappedFrom255() {
        let entity = makeEntity(domain: "light", state: "on",
                                attrs: HAAttributes(brightness: 128))
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        guard let bright = caps.first(where: { $0.kind == .brightness }),
              case .brightness(let value) = bright else {
            XCTFail("Expected brightness capability"); return
        }
        // 128/255 ≈ 0.502
        XCTAssertEqual(value, Double(128) / 255.0, accuracy: 0.01)
    }

    // MARK: - Climate capabilities

    func testClimate_CurrentTemp() {
        let entity = makeEntity(domain: "climate", state: "heat",
                                attrs: HAAttributes(currentTemperature: 22.5))
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.currentTemperature(celsius: 22.5)))
    }

    func testClimate_TargetTemp() {
        let entity = makeEntity(domain: "climate", state: "heat",
                                attrs: HAAttributes(temperature: 21.0))
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.targetTemperature(celsius: 21.0)))
    }

    func testClimate_HVACMode_Heat() {
        let entity = makeEntity(domain: "climate", state: "heat")
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.hvacMode(.heat)))
    }

    func testClimate_HVACMode_Off() {
        let entity = makeEntity(domain: "climate", state: "off")
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.hvacMode(.off)))
    }

    // MARK: - Sensor capabilities

    func testSensor_Temperature() {
        let entity = makeEntity(domain: "sensor", state: "22.5",
                                attrs: HAAttributes(deviceClass: "temperature"))
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.currentTemperature(celsius: 22.5)))
    }

    func testSensor_Humidity_NumericState() {
        let entity = makeEntity(domain: "sensor", state: "45",
                                attrs: HAAttributes(deviceClass: "humidity"))
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.humidity(percent: 45)))
    }

    func testSensor_Humidity_UnavailableState_Skipped() {
        let entity = makeEntity(domain: "sensor", state: "unavailable",
                                attrs: HAAttributes(deviceClass: "humidity"))
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        // Should NOT contain a humidity capability with bogus value 0
        XCTAssertNil(caps.first(where: { $0.kind == .humidity }))
    }

    func testSensor_Battery() {
        let entity = makeEntity(domain: "sensor", state: "87",
                                attrs: HAAttributes(deviceClass: "battery"))
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.batteryLevel(percent: 87)))
    }

    func testSensor_Battery_UnavailableState_Skipped() {
        let entity = makeEntity(domain: "sensor", state: "unknown",
                                attrs: HAAttributes(deviceClass: "battery"))
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertNil(caps.first(where: { $0.kind == .batteryLevel }))
    }

    // MARK: - Media player capabilities

    func testMediaPlayer_Playing() {
        let entity = makeEntity(domain: "media_player", state: "playing")
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.playback(state: .playing)))
    }

    func testMediaPlayer_Paused() {
        let entity = makeEntity(domain: "media_player", state: "paused")
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.playback(state: .paused)))
    }

    func testMediaPlayer_Volume() {
        let entity = makeEntity(domain: "media_player", state: "playing",
                                attrs: HAAttributes(volumeLevel: 0.65))
        let caps = HomeAssistantCapabilityMapper.capabilities(from: entity)
        XCTAssertTrue(caps.contains(.volume(percent: 65)))
    }

    // MARK: - Helpers

    /// Builds a minimal HAEntityState from JSON since the struct uses
    /// let properties and Codable synthesis.
    private func makeEntity(
        domain: String,
        state: String = "on",
        attrs: HAAttributes? = nil
    ) -> HAEntityState {
        var attrDict: [String: Any] = [:]
        if let a = attrs {
            // Extract known fields for re-encoding
            if let b = a.brightness { attrDict["brightness"] = b }
            if let ct = a.currentTemperature { attrDict["current_temperature"] = ct }
            if let t = a.temperature { attrDict["temperature"] = t }
            if let dc = a.deviceClass { attrDict["device_class"] = dc }
            if let vl = a.volumeLevel { attrDict["volume_level"] = vl }
        }
        let json: [String: Any] = [
            "entity_id": "\(domain).test_device",
            "state": state,
            "last_changed": "2026-04-15T12:00:00Z",
            "last_updated": "2026-04-15T12:00:00Z",
            "attributes": attrDict,
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(HAEntityState.self, from: data)
    }
}

// MARK: - HAAttributes test helper

/// Builds HAAttributes from JSON since the struct uses a custom
/// init(from decoder:) and has mixed let/var properties.
private func makeAttrs(_ dict: [String: Any] = [:]) -> HAAttributes {
    var json = dict
    // Ensure we can decode
    if let data = try? JSONSerialization.data(withJSONObject: json),
       let attrs = try? JSONDecoder().decode(HAAttributes.self, from: data) {
        return attrs
    }
    // Fallback: empty attrs from empty JSON object
    let empty = try! JSONDecoder().decode(HAAttributes.self, from: Data("{}".utf8))
    return empty
}

private extension HAAttributes {
    init(
        brightness: Int? = nil,
        currentTemperature: Double? = nil,
        temperature: Double? = nil,
        deviceClass: String? = nil,
        volumeLevel: Double? = nil
    ) {
        var dict: [String: Any] = [:]
        if let b = brightness { dict["brightness"] = b }
        if let ct = currentTemperature { dict["current_temperature"] = ct }
        if let t = temperature { dict["temperature"] = t }
        if let dc = deviceClass { dict["device_class"] = dc }
        if let vl = volumeLevel { dict["volume_level"] = vl }
        self = makeAttrs(dict)
    }
}
