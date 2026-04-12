//
//  NestCapabilityMapper.swift
//  house connect
//
//  Translates Google SDM trait payloads into our unified Capability enum,
//  and in the reverse direction turns AccessoryCommands into SDM command
//  strings + parameter dictionaries.
//
//  Following the SmartThingsCapabilityMapper pattern: pure enum, all
//  static methods, zero state.
//
//  SDM trait reference:
//    https://developers.google.com/nest/device-access/traits
//
//  NOTE: Nest Protect is NOT in the SDM program. Smoke/CO capabilities
//  are only populated by DemoNestProvider.
//

import Foundation

enum NestCapabilityMapper {

    // MARK: - Traits → Capabilities

    static func capabilities(from device: NestSDMDTO.Device) -> [Capability] {
        var caps: [Capability] = []

        // Connectivity → isReachable (handled separately by the provider,
        // not modeled as a capability)

        // Temperature
        if let t = device.trait("sdm.devices.traits.Temperature"),
           let celsius = t.double("temperatureAmbientCelsius") {
            caps.append(.currentTemperature(celsius: celsius))
        }

        // Humidity
        if let h = device.trait("sdm.devices.traits.Humidity"),
           let pct = h.double("ambientHumidityPercent") {
            caps.append(.humidity(percent: Int(pct.rounded())))
        }

        // Thermostat mode
        if let m = device.trait("sdm.devices.traits.ThermostatMode"),
           let mode = m.string("mode") {
            switch mode.uppercased() {
            case "OFF":       caps.append(.hvacMode(.off))
            case "HEAT":      caps.append(.hvacMode(.heat))
            case "COOL":      caps.append(.hvacMode(.cool))
            case "HEATCOOL":  caps.append(.hvacMode(.auto))
            default: break
            }
            // Power derived from mode: off means not actively running
            caps.append(.power(isOn: mode.uppercased() != "OFF"))
        }

        // Thermostat temperature setpoint
        if let sp = device.trait("sdm.devices.traits.ThermostatTemperatureSetpoint") {
            // SDM uses heatCelsius / coolCelsius depending on mode.
            // In HEATCOOL (auto) mode, BOTH are present — our unified
            // model only supports a single targetTemperature, so we use
            // the midpoint. The round-trip command (`SetRange`) recreates
            // a ±1° band around whatever the user sets. This loses the
            // exact original heat/cool split, but is acceptable until we
            // add dual-setpoint capability cases (Phase 7+).
            let heat = sp.double("heatCelsius")
            let cool = sp.double("coolCelsius")
            if let heat, let cool {
                // HEATCOOL mode — use midpoint
                caps.append(.targetTemperature(celsius: (heat + cool) / 2.0))
            } else if let heat {
                caps.append(.targetTemperature(celsius: heat))
            } else if let cool {
                caps.append(.targetTemperature(celsius: cool))
            }
        }

        return caps
    }

    // MARK: - Device → Category

    static func category(for device: NestSDMDTO.Device) -> Accessory.Category {
        let type = device.type.uppercased()
        if type.contains("THERMOSTAT") { return .thermostat }
        if type.contains("CAMERA") || type.contains("DOORBELL") { return .camera }
        if type.contains("DISPLAY") { return .sensor }
        return .other
    }

    // MARK: - Display name

    static func displayName(for device: NestSDMDTO.Device) -> String {
        // 1. Custom name from Info trait
        if let info = device.trait("sdm.devices.traits.Info"),
           let name = info.string("customName"), !name.isEmpty {
            return name
        }
        // 2. Parent relation display name (room name)
        if let relation = device.parentRelations?.first,
           let name = relation.displayName, !name.isEmpty {
            return name
        }
        // 3. Fallback to device type
        return typeFriendlyName(device.type)
    }

    /// Extracts the room resource ID from the first parent relation.
    static func roomID(for device: NestSDMDTO.Device) -> String? {
        guard let parent = device.parentRelations?.first?.parent else { return nil }
        return parent.components(separatedBy: "/").last
    }

    // MARK: - Command → SDM

    /// Returns `nil` for unsupported commands — the provider surfaces
    /// `.unsupportedCommand` in that case.
    static func sdmCommand(
        for command: AccessoryCommand,
        currentMode: HVACMode? = nil
    ) -> (command: String, params: [String: NestSDMDTO.AnyCodableValue]?)? {
        switch command {
        case .setTargetTemperature(let celsius):
            // Route to the right setpoint command based on current mode.
            let mode = currentMode ?? .heat
            switch mode {
            case .heat, .off:
                return (
                    "sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
                    ["heatCelsius": .double(celsius)]
                )
            case .cool:
                return (
                    "sdm.devices.commands.ThermostatTemperatureSetpoint.SetCool",
                    ["coolCelsius": .double(celsius)]
                )
            case .auto:
                // HEATCOOL needs both heat and cool — set both to same
                // value as a simplification; the user can adjust.
                return (
                    "sdm.devices.commands.ThermostatTemperatureSetpoint.SetRange",
                    ["heatCelsius": .double(celsius - 1), "coolCelsius": .double(celsius + 1)]
                )
            }

        case .setHVACMode(let mode):
            let sdmMode: String
            switch mode {
            case .off:  sdmMode = "OFF"
            case .heat: sdmMode = "HEAT"
            case .cool: sdmMode = "COOL"
            case .auto: sdmMode = "HEATCOOL"
            }
            return (
                "sdm.devices.commands.ThermostatMode.SetMode",
                ["mode": .string(sdmMode)]
            )

        case .setPower(let on):
            // No direct power command in SDM. Map to mode off/heat.
            let sdmMode = on ? "HEAT" : "OFF"
            return (
                "sdm.devices.commands.ThermostatMode.SetMode",
                ["mode": .string(sdmMode)]
            )

        default:
            // Brightness, hue, volume, media transport, speaker grouping,
            // selfTest, etc. — none of these apply to SDM devices.
            return nil
        }
    }

    // MARK: - Helpers

    private static func typeFriendlyName(_ type: String) -> String {
        if type.contains("THERMOSTAT") { return "Nest Thermostat" }
        if type.contains("CAMERA") { return "Nest Cam" }
        if type.contains("DOORBELL") { return "Nest Doorbell" }
        if type.contains("DISPLAY") { return "Nest Hub" }
        return "Nest Device"
    }
}
