//
//  SmartThingsCapabilityMapper.swift
//  house connect
//
//  Translates SmartThings' capability/attribute tree into our unified
//  `Capability` enum, and in the opposite direction turns an
//  `AccessoryCommand` into one or more SmartThings `Command` structs.
//
//  This is the ONE place in the SmartThings stack that knows about our
//  domain model. Keeping it isolated means adding a new SmartThings
//  capability is a local change instead of touching the provider.
//
//  Capability reference:
//    https://developer.smartthings.com/docs/devices/capabilities/capabilities-reference
//

import Foundation

enum SmartThingsCapabilityMapper {

    // MARK: - Status → Capabilities

    /// Extracts our unified `Capability` values from a status payload.
    /// Unknown/unsupported capabilities are silently skipped — absence is
    /// fine, we just won't render a control for them.
    static func capabilities(from status: SmartThingsDTO.DeviceStatus) -> [Capability] {
        var caps: [Capability] = []

        // switch → power
        if let v = status.mainAttribute(capability: "switch", attribute: "switch")?.asBool {
            caps.append(.power(isOn: v))
        }

        // switchLevel → brightness (0–100 → 0.0–1.0)
        if let pct = status.mainAttribute(capability: "switchLevel", attribute: "level")?.asDouble {
            caps.append(.brightness(value: max(0, min(1, pct / 100.0))))
        }

        // colorControl → hue / saturation
        if let h = status.mainAttribute(capability: "colorControl", attribute: "hue")?.asDouble {
            // SmartThings hue is 0–100 (percent of the wheel), not degrees.
            caps.append(.hue(degrees: h * 3.6))
        }
        if let s = status.mainAttribute(capability: "colorControl", attribute: "saturation")?.asDouble {
            caps.append(.saturation(value: max(0, min(1, s / 100.0))))
        }

        // colorTemperature → mireds (SmartThings reports Kelvin, we store mireds)
        if let k = status.mainAttribute(capability: "colorTemperature", attribute: "colorTemperature")?.asDouble, k > 0 {
            caps.append(.colorTemperature(mireds: Int((1_000_000.0 / k).rounded())))
        }

        // temperatureMeasurement → currentTemperature
        if let t = status.mainAttribute(capability: "temperatureMeasurement", attribute: "temperature")?.asDouble {
            let unit = status.mainAttribute(capability: "temperatureMeasurement", attribute: "temperature")?.asString
            caps.append(.currentTemperature(celsius: normalizeTemperature(t, unit: unit)))
        }

        // thermostatHeatingSetpoint / thermostatCoolingSetpoint → targetTemperature
        // SmartThings often splits heat/cool set points. Prefer heating if present.
        if let t = status.mainAttribute(capability: "thermostatHeatingSetpoint",
                                        attribute: "heatingSetpoint")?.asDouble {
            caps.append(.targetTemperature(celsius: t))
        } else if let t = status.mainAttribute(capability: "thermostatCoolingSetpoint",
                                               attribute: "coolingSetpoint")?.asDouble {
            caps.append(.targetTemperature(celsius: t))
        }

        // thermostatMode → hvacMode. SmartThings publishes one of
        // "off" / "heat" / "cool" / "auto" (plus a few rare modes like
        // "emergency heat" and "dry" that we collapse into the closest
        // canonical value). Anything we don't recognize is skipped —
        // absence is the correct "unknown" signal here.
        if let raw = status.mainAttribute(capability: "thermostatMode",
                                          attribute: "thermostatMode")?.asString {
            switch raw.lowercased() {
            case "off": caps.append(.hvacMode(.off))
            case "heat", "emergency heat": caps.append(.hvacMode(.heat))
            case "cool": caps.append(.hvacMode(.cool))
            case "auto", "autochangeover": caps.append(.hvacMode(.auto))
            default: break
            }
        }

        // contactSensor
        if let s = status.mainAttribute(capability: "contactSensor", attribute: "contact")?.asString {
            caps.append(.contactSensor(isOpen: s == "open"))
        }

        // motionSensor
        if let s = status.mainAttribute(capability: "motionSensor", attribute: "motion")?.asString {
            caps.append(.motionSensor(isDetected: s == "active"))
        }

        // battery
        if let pct = status.mainAttribute(capability: "battery", attribute: "battery")?.asInt {
            caps.append(.batteryLevel(percent: pct))
        }

        // mediaPlayback → playback state
        // SmartThings reports: "playing", "paused", "stopped",
        // "fast forwarding", "rewinding", "buffering".
        if let raw = status.mainAttribute(capability: "mediaPlayback", attribute: "playbackStatus")?.asString {
            caps.append(.playback(state: playbackState(from: raw)))
        }

        // audioVolume → volume (0–100 integer)
        if let v = status.mainAttribute(capability: "audioVolume", attribute: "volume")?.asInt {
            caps.append(.volume(percent: max(0, min(100, v))))
        }

        // audioMute → mute (ST uses "muted" / "unmuted" strings)
        if let m = status.mainAttribute(capability: "audioMute", attribute: "mute")?.asString {
            caps.append(.mute(isMuted: m == "muted"))
        }

        // audioTrackData → now playing.
        // SmartThings packs this as a JSON OBJECT, but our AttributeValue
        // decoder only handles primitives. Wiring up full object decoding
        // for this one field is low value in Phase 3a (Sonos is the first
        // real media test case anyway), so we defer it. When we need
        // Samsung Frame / soundbar metadata, we'll teach AttributeValue
        // to carry an arbitrary JSON blob.

        return caps
    }

    /// Maps SmartThings' free-text playback status to our canonical enum.
    private static func playbackState(from raw: String) -> PlaybackState {
        switch raw.lowercased() {
        case "playing": .playing
        case "paused": .paused
        case "stopped": .stopped
        case "buffering", "fast forwarding", "rewinding": .transitioning
        default: .unknown
        }
    }

    // MARK: - Device → Category

    /// Best-effort category guess from the device's advertised capability list.
    /// SmartThings devices don't have a clean "category" field, so we infer.
    static func category(for device: SmartThingsDTO.Device) -> Accessory.Category {
        let caps = Set(device.components?.flatMap { $0.capabilities.map(\.id) } ?? [])

        if caps.contains("thermostat") || caps.contains("thermostatMode") {
            return .thermostat
        }
        if caps.contains("lock") { return .lock }
        if caps.contains("videoStream") || caps.contains("videoCamera") { return .camera }
        if caps.contains("windowShade") || caps.contains("windowShadeLevel") { return .blinds }
        if caps.contains("fanSpeed") { return .fan }
        // TV detection — must run BEFORE the generic speaker check,
        // because Frame TVs also advertise `audioVolume`/`mediaPlayback`
        // and we want them to route to the bespoke TV screen instead
        // of the generic speaker screen. SmartThings identifies TVs
        // via `tvChannel` / `mediaInputSource` / Samsung's
        // vendor-specific `samsungvd.mediaInputSource`.
        if caps.contains("tvChannel")
            || caps.contains("mediaInputSource")
            || caps.contains("samsungvd.mediaInputSource") {
            return .television
        }
        if caps.contains("audioVolume") || caps.contains("mediaPlayback") { return .speaker }
        if caps.contains("contactSensor") || caps.contains("motionSensor")
            || caps.contains("temperatureMeasurement") {
            return .sensor
        }
        if caps.contains("colorControl") || caps.contains("colorTemperature")
            || caps.contains("switchLevel") {
            return .light
        }
        if caps.contains("switch") {
            // Plain on/off → could be a plug or a wall switch. Default to outlet
            // since the SmartThings app treats bare `switch` devices that way.
            return .outlet
        }
        return .other
    }

    // MARK: - AccessoryCommand → SmartThings Command(s)

    /// Translates a unified command into the wire-format commands to POST.
    /// Returns an array because some commands fan out (e.g. hue+saturation).
    static func smartThingsCommands(for command: AccessoryCommand) -> [SmartThingsDTO.Command] {
        switch command {
        case .setPower(let on):
            return [SmartThingsDTO.Command(
                capability: "switch",
                command: on ? "on" : "off"
            )]

        case .setBrightness(let value):
            let pct = Int((max(0, min(1, value)) * 100).rounded())
            return [SmartThingsDTO.Command(
                capability: "switchLevel",
                command: "setLevel",
                arguments: [.int(pct)]
            )]

        case .setHue(let degrees):
            // Convert degrees (0–360) → SmartThings percent (0–100).
            let pct = max(0, min(100, Int((degrees / 3.6).rounded())))
            return [SmartThingsDTO.Command(
                capability: "colorControl",
                command: "setHue",
                arguments: [.int(pct)]
            )]

        case .setSaturation(let value):
            let pct = Int((max(0, min(1, value)) * 100).rounded())
            return [SmartThingsDTO.Command(
                capability: "colorControl",
                command: "setSaturation",
                arguments: [.int(pct)]
            )]

        case .setColorTemperature(let mireds):
            // SmartThings wants Kelvin.
            let kelvin = Int((1_000_000.0 / Double(max(1, mireds))).rounded())
            return [SmartThingsDTO.Command(
                capability: "colorTemperature",
                command: "setColorTemperature",
                arguments: [.int(kelvin)]
            )]

        case .setTargetTemperature(let celsius):
            return [SmartThingsDTO.Command(
                capability: "thermostatHeatingSetpoint",
                command: "setHeatingSetpoint",
                arguments: [.double(celsius)]
            )]

        case .setHVACMode(let mode):
            // thermostatMode.setThermostatMode expects the raw string
            // matching the device's supportedThermostatModes attribute.
            // All four canonical values map 1:1.
            return [SmartThingsDTO.Command(
                capability: "thermostatMode",
                command: "setThermostatMode",
                arguments: [.string(mode.rawValue)]
            )]

        // MARK: Media transport (SmartThings mediaPlayback / audioVolume / audioMute)

        case .play:
            return [SmartThingsDTO.Command(capability: "mediaPlayback", command: "play")]

        case .pause:
            return [SmartThingsDTO.Command(capability: "mediaPlayback", command: "pause")]

        case .stop:
            return [SmartThingsDTO.Command(capability: "mediaPlayback", command: "stop")]

        case .next:
            return [SmartThingsDTO.Command(capability: "mediaTrackControl", command: "nextTrack")]

        case .previous:
            return [SmartThingsDTO.Command(capability: "mediaTrackControl", command: "previousTrack")]

        case .setVolume(let percent):
            return [SmartThingsDTO.Command(
                capability: "audioVolume",
                command: "setVolume",
                arguments: [.int(max(0, min(100, percent)))]
            )]

        case .setGroupVolume:
            // SmartThings has no native group-volume concept on the
            // generic audioVolume capability; Samsung's `audioGroup`
            // lives on Soundbar/multiroom devices only and the argument
            // shape varies by generation. Rather than guess, surface
            // as unsupported — the UI can hide or iterate member
            // volumes itself as a fallback.
            return []

        case .setMute(let muted):
            return [SmartThingsDTO.Command(
                capability: "audioMute",
                command: muted ? "mute" : "unmute"
            )]

        case .setShuffle, .setRepeatMode:
            // SmartThings has `mediaPlaybackShuffle` and `mediaPlaybackRepeat`
            // capabilities on paper, but they're almost never exposed on the
            // media players we actually see in customer accounts (and the few
            // devices that do implement them use bespoke per-vendor argument
            // shapes). Rather than hit the cloud with a 422-generating command
            // that confuses the user, return empty so SmartThingsProvider
            // surfaces a clean `.unsupportedCommand` and the UI shows a
            // "not supported on this device" toast. Revisit if/when we have
            // a confirmed working device to test against.
            return []

        case .joinSpeakerGroup, .leaveSpeakerGroup:
            // Zone grouping is a Sonos-only concept in this app today.
            // SmartThings' `audioGroup` capability technically exists
            // but only on Samsung Soundbar / multiroom devices and the
            // argument shape differs by device generation — not safe
            // to fan out blindly. Return empty so the provider surfaces
            // `.unsupportedCommand`, matching the existing pattern.
            return []

        case .selfTest:
            // Self-test is a Nest Protect concept. SmartThings has no
            // equivalent — return empty so the provider surfaces
            // `.unsupportedCommand`.
            return []
        }
    }

    // MARK: - Helpers

    // MARK: - Single-event SSE mapping

    /// Maps a single SSE device event into a Capability value. Returns nil
    /// if the capability/attribute combination is unrecognized. Used by the
    /// SSE event handler to apply incremental state updates without a full
    /// device status re-fetch.
    static func capability(
        fromCapability capName: String,
        attribute: String,
        value: SmartThingsDTO.AttributeValue
    ) -> Capability? {
        switch (capName, attribute) {
        case ("switch", "switch"):
            return value.asBool.map { .power(isOn: $0) }
        case ("switchLevel", "level"):
            return value.asDouble.map { .brightness(value: max(0, min(1, $0 / 100.0))) }
        case ("colorControl", "hue"):
            return value.asDouble.map { .hue(degrees: $0 * 3.6) }
        case ("colorControl", "saturation"):
            return value.asDouble.map { .saturation(value: max(0, min(1, $0 / 100.0))) }
        case ("colorTemperature", "colorTemperature"):
            guard let k = value.asDouble, k > 0 else { return nil }
            return .colorTemperature(mireds: Int((1_000_000.0 / k).rounded()))
        case ("temperatureMeasurement", "temperature"):
            return value.asDouble.map { .currentTemperature(celsius: $0) }
        case ("thermostatHeatingSetpoint", "heatingSetpoint"):
            return value.asDouble.map { .targetTemperature(celsius: $0) }
        case ("thermostatCoolingSetpoint", "coolingSetpoint"):
            return value.asDouble.map { .targetTemperature(celsius: $0) }
        case ("thermostatMode", "thermostatMode"):
            guard let raw = value.asString else { return nil }
            switch raw.lowercased() {
            case "off": return .hvacMode(.off)
            case "heat", "emergency heat": return .hvacMode(.heat)
            case "cool": return .hvacMode(.cool)
            case "auto", "autochangeover": return .hvacMode(.auto)
            default: return nil
            }
        case ("contactSensor", "contact"):
            return value.asString.map { .contactSensor(isOpen: $0 == "open") }
        case ("motionSensor", "motion"):
            return value.asString.map { .motionSensor(isDetected: $0 == "active") }
        case ("battery", "battery"):
            return value.asInt.map { .batteryLevel(percent: $0) }
        case ("mediaPlayback", "playbackStatus"):
            return value.asString.map { .playback(state: playbackState(from: $0)) }
        case ("audioVolume", "volume"):
            return value.asInt.map { .volume(percent: max(0, min(100, $0))) }
        case ("audioMute", "mute"):
            return value.asString.map { .mute(isMuted: $0 == "muted") }
        default:
            return nil
        }
    }

    /// SmartThings temperature values are reported in the device's configured
    /// unit. We normalize to Celsius because that's what our `Capability`
    /// enum uses everywhere else.
    private static func normalizeTemperature(_ value: Double, unit: String?) -> Double {
        guard let unit else { return value }
        if unit.uppercased() == "F" {
            return (value - 32.0) * 5.0 / 9.0
        }
        return value
    }
}
