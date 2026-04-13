//
//  NestCapabilityMapperTests.swift
//  house connectTests
//
//  Tests for the SDM trait → unified Capability/Category/Command mapping.
//  Pure functions, no network, no side effects.
//

import XCTest
@testable import house_connect

@MainActor
final class NestCapabilityMapperTests: XCTestCase {

    // MARK: - Category inference

    func testCategory_Thermostat() {
        let device = makeDevice(type: "sdm.devices.types.THERMOSTAT")
        XCTAssertEqual(NestCapabilityMapper.category(for: device), .thermostat)
    }

    func testCategory_Camera() {
        let device = makeDevice(type: "sdm.devices.types.CAMERA")
        XCTAssertEqual(NestCapabilityMapper.category(for: device), .camera)
    }

    func testCategory_Doorbell() {
        let device = makeDevice(type: "sdm.devices.types.DOORBELL")
        XCTAssertEqual(NestCapabilityMapper.category(for: device), .camera)
    }

    func testCategory_Display() {
        let device = makeDevice(type: "sdm.devices.types.DISPLAY")
        XCTAssertEqual(NestCapabilityMapper.category(for: device), .sensor)
    }

    func testCategory_Unknown() {
        let device = makeDevice(type: "sdm.devices.types.UNKNOWN_FUTURE")
        XCTAssertEqual(NestCapabilityMapper.category(for: device), .other)
    }

    // MARK: - Temperature capability

    func testTemperature_MapsAmbientCelsius() {
        let device = makeDevice(traits: [
            "sdm.devices.traits.Temperature": .init(values: [
                "temperatureAmbientCelsius": .double(22.5)
            ])
        ])
        let caps = NestCapabilityMapper.capabilities(from: device)
        XCTAssertTrue(caps.contains(.currentTemperature(celsius: 22.5)))
    }

    // MARK: - Humidity capability

    func testHumidity_MapsPercent() {
        let device = makeDevice(traits: [
            "sdm.devices.traits.Humidity": .init(values: [
                "ambientHumidityPercent": .double(45.3)
            ])
        ])
        let caps = NestCapabilityMapper.capabilities(from: device)
        XCTAssertTrue(caps.contains(.humidity(percent: 45)))
    }

    // MARK: - Thermostat mode

    func testHVACMode_Heat() {
        let device = makeDevice(traits: [
            "sdm.devices.traits.ThermostatMode": .init(values: [
                "mode": .string("HEAT")
            ])
        ])
        let caps = NestCapabilityMapper.capabilities(from: device)
        XCTAssertTrue(caps.contains(.hvacMode(.heat)))
        XCTAssertTrue(caps.contains(.power(isOn: true)))
    }

    func testHVACMode_Off() {
        let device = makeDevice(traits: [
            "sdm.devices.traits.ThermostatMode": .init(values: [
                "mode": .string("OFF")
            ])
        ])
        let caps = NestCapabilityMapper.capabilities(from: device)
        XCTAssertTrue(caps.contains(.hvacMode(.off)))
        XCTAssertTrue(caps.contains(.power(isOn: false)))
    }

    func testHVACMode_HeatCool_MapsToAuto() {
        let device = makeDevice(traits: [
            "sdm.devices.traits.ThermostatMode": .init(values: [
                "mode": .string("HEATCOOL")
            ])
        ])
        let caps = NestCapabilityMapper.capabilities(from: device)
        XCTAssertTrue(caps.contains(.hvacMode(.auto)))
    }

    // MARK: - Temperature setpoint

    func testSetpoint_HeatOnly() {
        let device = makeDevice(traits: [
            "sdm.devices.traits.ThermostatTemperatureSetpoint": .init(values: [
                "heatCelsius": .double(21.0)
            ])
        ])
        let caps = NestCapabilityMapper.capabilities(from: device)
        XCTAssertTrue(caps.contains(.targetTemperature(celsius: 21.0)))
    }

    func testSetpoint_CoolOnly() {
        let device = makeDevice(traits: [
            "sdm.devices.traits.ThermostatTemperatureSetpoint": .init(values: [
                "coolCelsius": .double(24.0)
            ])
        ])
        let caps = NestCapabilityMapper.capabilities(from: device)
        XCTAssertTrue(caps.contains(.targetTemperature(celsius: 24.0)))
    }

    func testSetpoint_HeatCool_UsesMidpoint() {
        let device = makeDevice(traits: [
            "sdm.devices.traits.ThermostatTemperatureSetpoint": .init(values: [
                "heatCelsius": .double(20.0),
                "coolCelsius": .double(24.0),
            ])
        ])
        let caps = NestCapabilityMapper.capabilities(from: device)
        guard let target = caps.first(where: { $0.kind == .targetTemperature }),
              case .targetTemperature(let celsius) = target else {
            XCTFail("Expected targetTemperature"); return
        }
        XCTAssertEqual(celsius, 22.0, accuracy: 0.01)
    }

    // MARK: - Display name

    func testDisplayName_CustomName() {
        let device = makeDevice(traits: [
            "sdm.devices.traits.Info": .init(values: [
                "customName": .string("Living Room Thermostat")
            ])
        ])
        XCTAssertEqual(NestCapabilityMapper.displayName(for: device), "Living Room Thermostat")
    }

    func testDisplayName_FallsBackToParentRelation() {
        let device = NestSDMDTO.Device(
            name: "enterprises/proj/devices/abc",
            type: "sdm.devices.types.THERMOSTAT",
            traits: [:],
            parentRelations: [
                NestSDMDTO.ParentRelation(parent: "enterprises/proj/structures/s1/rooms/r1",
                                           displayName: "Kitchen")
            ]
        )
        XCTAssertEqual(NestCapabilityMapper.displayName(for: device), "Kitchen")
    }

    func testDisplayName_FallsBackToType() {
        let device = makeDevice(type: "sdm.devices.types.THERMOSTAT", traits: [:])
        XCTAssertEqual(NestCapabilityMapper.displayName(for: device), "Nest Thermostat")
    }

    // MARK: - Command mapping

    func testSetTargetTemp_Heat_ProducesSetHeat() {
        let result = NestCapabilityMapper.sdmCommand(for: .setTargetTemperature(21.0), currentMode: .heat)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.command.contains("SetHeat"))
    }

    func testSetTargetTemp_Cool_ProducesSetCool() {
        let result = NestCapabilityMapper.sdmCommand(for: .setTargetTemperature(24.0), currentMode: .cool)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.command.contains("SetCool"))
    }

    func testSetTargetTemp_Auto_ProducesSetRange() {
        let result = NestCapabilityMapper.sdmCommand(for: .setTargetTemperature(22.0), currentMode: .auto)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.command.contains("SetRange"))
    }

    func testSetHVACMode_Maps() {
        for (input, expected) in [(HVACMode.off, "OFF"), (.heat, "HEAT"), (.cool, "COOL"), (.auto, "HEATCOOL")] {
            let result = NestCapabilityMapper.sdmCommand(for: .setHVACMode(input))
            XCTAssertNotNil(result)
            XCTAssertTrue(result!.command.contains("SetMode"))
            if case .string(let mode) = result!.params?["mode"] {
                XCTAssertEqual(mode, expected)
            } else {
                XCTFail("Expected mode param for \(input)")
            }
        }
    }

    func testUnsupportedCommand_ReturnsNil() {
        XCTAssertNil(NestCapabilityMapper.sdmCommand(for: .play))
        XCTAssertNil(NestCapabilityMapper.sdmCommand(for: .setBrightness(0.5)))
        XCTAssertNil(NestCapabilityMapper.sdmCommand(for: .selfTest))
    }

    // MARK: - Room ID extraction

    func testRoomID_ExtractsFromParentRelation() {
        let device = NestSDMDTO.Device(
            name: "enterprises/proj/devices/abc",
            type: "sdm.devices.types.THERMOSTAT",
            traits: [:],
            parentRelations: [
                NestSDMDTO.ParentRelation(
                    parent: "enterprises/proj/structures/s1/rooms/room123",
                    displayName: "Bedroom"
                )
            ]
        )
        XCTAssertEqual(NestCapabilityMapper.roomID(for: device), "room123")
    }

    func testRoomID_NilWithoutRelations() {
        let device = makeDevice()
        XCTAssertNil(NestCapabilityMapper.roomID(for: device))
    }

    // MARK: - Helpers

    private func makeDevice(
        type: String = "sdm.devices.types.THERMOSTAT",
        traits: [String: NestSDMDTO.TraitPayload] = [:]
    ) -> NestSDMDTO.Device {
        NestSDMDTO.Device(
            name: "enterprises/proj/devices/\(UUID().uuidString)",
            type: type,
            traits: traits,
            parentRelations: nil
        )
    }
}
