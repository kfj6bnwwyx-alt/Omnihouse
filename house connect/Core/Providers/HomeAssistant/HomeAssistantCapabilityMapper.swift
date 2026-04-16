//
//  HomeAssistantCapabilityMapper.swift
//  house connect
//
//  Maps Home Assistant entities → our unified Accessory/Capability model.
//  This is the ONLY file that knows about both HA's entity format and our
//  domain model. Everything else in the HA provider stack speaks one or
//  the other.
//

import Foundation

enum HomeAssistantCapabilityMapper {

    // MARK: - Entity → Capabilities

    /// Extract capabilities from a HA entity state based on its domain.
    static func capabilities(from entity: HAEntityState) -> [Capability] {
        switch entity.domain {
        case "light":       return lightCapabilities(entity)
        case "switch":      return switchCapabilities(entity)
        case "climate":     return climateCapabilities(entity)
        case "media_player": return mediaPlayerCapabilities(entity)
        case "sensor":      return sensorCapabilities(entity)
        case "binary_sensor": return binarySensorCapabilities(entity)
        case "camera":      return cameraCapabilities(entity)
        case "fan":         return fanCapabilities(entity)
        case "cover":       return coverCapabilities(entity)
        case "lock":        return lockCapabilities(entity)
        default:            return genericCapabilities(entity)
        }
    }

    /// Determine the accessory category from a HA entity's domain + device class.
    static func category(from entity: HAEntityState) -> Accessory.Category {
        switch entity.domain {
        case "light":         return .light
        case "switch":        return .switch
        case "climate":       return .thermostat
        case "camera":        return .camera
        case "fan":           return .fan
        case "cover":         return .blinds
        case "lock":          return .lock
        case "media_player":
            if entity.attributes.deviceClass == "tv" {
                return .television
            }
            return .speaker
        case "sensor", "binary_sensor":
            if entity.attributes.deviceClass == "smoke" ||
               entity.attributes.deviceClass == "carbon_monoxide" {
                return .smokeAlarm
            }
            return .sensor
        default:
            return .other
        }
    }

    /// Map an AccessoryCommand to a HA service call (domain, service, data).
    static func serviceCall(
        for command: AccessoryCommand,
        entity: HAEntityState
    ) -> (domain: String, service: String, data: [String: AnyCodableValue]) {
        let domain = entity.domain

        switch command {
        case .setPower(let on):
            // Domain-specific power routing: locks and covers use
            // their own service verbs, not generic turn_on/turn_off.
            switch domain {
            case "lock":
                return ("lock", on ? "lock" : "unlock", [:])
            case "cover":
                return ("cover", on ? "open_cover" : "close_cover", [:])
            default:
                return (domain, on ? "turn_on" : "turn_off", [:])
            }

        case .setBrightness(let value):
            // Our model: 0.0-1.0, HA: 0-255
            let haBrightness = Int(value * 255.0)
            return ("light", "turn_on", ["brightness": .int(haBrightness)])

        case .setHue(let degrees):
            // HA uses [hue, saturation] as hs_color
            // We only set hue; preserve existing saturation
            let sat = entity.attributes.hsColor?.last ?? 100.0
            return ("light", "turn_on", [
                "hs_color": .array([.double(degrees), .double(sat)])
            ])

        case .setSaturation(let value):
            // Our model: 0.0-1.0, HA: 0-100
            let hue = entity.attributes.hsColor?.first ?? 0.0
            return ("light", "turn_on", [
                "hs_color": .array([.double(hue), .double(value * 100.0)])
            ])

        case .setColorTemperature(let mireds):
            // HA accepts color_temp_kelvin — convert mireds → kelvin
            let kelvin = mireds > 0 ? 1_000_000 / mireds : 4000
            return ("light", "turn_on", ["color_temp_kelvin": .int(kelvin)])

        case .setTargetTemperature(let celsius):
            return ("climate", "set_temperature", ["temperature": .double(celsius)])

        case .setHVACMode(let mode):
            let haMode: String = switch mode {
            case .off: "off"
            case .heat: "heat"
            case .cool: "cool"
            case .auto: "auto"
            }
            return ("climate", "set_hvac_mode", ["hvac_mode": .string(haMode)])

        case .play:
            return ("media_player", "media_play", [:])
        case .pause:
            return ("media_player", "media_pause", [:])
        case .stop:
            return ("media_player", "media_stop", [:])
        case .next:
            return ("media_player", "media_next_track", [:])
        case .previous:
            return ("media_player", "media_previous_track", [:])

        case .setVolume(let percent):
            // Our model: 0-100, HA: 0.0-1.0
            return ("media_player", "volume_set", [
                "volume_level": .double(Double(percent) / 100.0)
            ])

        case .setGroupVolume(let percent):
            // HA doesn't have a native group volume — set on coordinator
            return ("media_player", "volume_set", [
                "volume_level": .double(Double(percent) / 100.0)
            ])

        case .setMute(let muted):
            return ("media_player", "volume_mute", [
                "is_volume_muted": .bool(muted)
            ])

        case .setShuffle(let on):
            return ("media_player", "shuffle_set", ["shuffle": .bool(on)])

        case .setRepeatMode(let mode):
            let haRepeat: String = switch mode {
            case .off: "off"
            case .all: "all"
            case .one: "one"
            }
            return ("media_player", "repeat_set", ["repeat": .string(haRepeat)])

        case .joinSpeakerGroup(let target):
            // Sonos via HA uses media_player.join with group_members
            return ("media_player", "join", [
                "group_members": .array([.string(target.nativeID)])
            ])

        case .leaveSpeakerGroup:
            return ("media_player", "unjoin", [:])

        case .selfTest:
            // No direct HA equivalent — try button.press if available
            return ("button", "press", [:])

        case .selectSource(let source):
            return ("media_player", "select_source", ["source": .string(source)])

        case .setPresetMode(let preset):
            return ("climate", "set_preset_mode", ["preset_mode": .string(preset)])

        case .setClimateFanMode(let mode):
            return ("climate", "set_fan_mode", ["fan_mode": .string(mode)])

        case .setFanSpeed(let percent):
            return ("fan", "set_percentage", ["percentage": .int(percent)])

        case .setFanDirection(let dir):
            return ("fan", "set_direction", ["direction": .string(dir)])

        case .setCoverPosition(let percent):
            return ("cover", "set_cover_position", ["position": .int(percent)])

        case .playMedia(let contentID, let contentType):
            return ("media_player", "play_media", [
                "media_content_id": .string(contentID),
                "media_content_type": .string(contentType)
            ])

        case .seekTo(let seconds):
            return ("media_player", "media_seek", [
                "seek_position": .double(seconds)
            ])

        case .setEffect(let effect):
            return ("light", "turn_on", ["effect": .string(effect)])
        }
    }

    // MARK: - Domain-specific capability extraction

    private static func lightCapabilities(_ entity: HAEntityState) -> [Capability] {
        var caps: [Capability] = []
        let attrs = entity.attributes

        // Power
        caps.append(.power(isOn: entity.state == "on"))

        // Brightness (HA: 0-255 → our 0.0-1.0)
        if let b = attrs.brightness {
            caps.append(.brightness(value: Double(b) / 255.0))
        }

        // Color via hs_color [hue 0-360, saturation 0-100]
        if let hs = attrs.hsColor, hs.count >= 2 {
            caps.append(.hue(degrees: hs[0]))
            caps.append(.saturation(value: hs[1] / 100.0))
        }

        // Color temperature (HA: kelvin → our mireds)
        if let kelvin = attrs.colorTempKelvin, kelvin > 0 {
            caps.append(.colorTemperature(mireds: 1_000_000 / kelvin))
        }

        // Light effects
        if let effect = attrs.effect {
            caps.append(.currentEffect(effect))
        }
        if let effects = attrs.effectList, !effects.isEmpty {
            caps.append(.effectList(effects))
        }

        return caps
    }

    private static func switchCapabilities(_ entity: HAEntityState) -> [Capability] {
        [.power(isOn: entity.state == "on")]
    }

    private static func climateCapabilities(_ entity: HAEntityState) -> [Capability] {
        var caps: [Capability] = []
        let attrs = entity.attributes

        if let current = attrs.currentTemperature {
            caps.append(.currentTemperature(celsius: current))
        }

        // Target temperature — handle dual-setpoint (heat_cool) mode
        // by using the midpoint, matching the existing Nest behavior.
        if let target = attrs.temperature {
            caps.append(.targetTemperature(celsius: target))
        } else if let high = attrs.targetTempHigh, let low = attrs.targetTempLow {
            caps.append(.targetTemperature(celsius: (high + low) / 2.0))
        }

        // HVAC mode
        let mode: HVACMode = switch entity.state {
        case "heat": .heat
        case "cool": .cool
        case "heat_cool", "auto": .auto
        default: .off
        }
        caps.append(.hvacMode(mode))

        // HVAC action — what the system is actually doing right now
        if let action = attrs.hvacAction {
            caps.append(.hvacAction(action))
        }

        if let h = attrs.raw?["current_humidity"]?.intValue {
            caps.append(.humidity(percent: h))
        }

        // Climate presets
        if let preset = attrs.presetMode {
            caps.append(.presetMode(preset))
        }
        if let presets = attrs.presetModes, !presets.isEmpty {
            caps.append(.presetModes(presets))
        }

        // Climate fan mode
        if let fm = attrs.fanMode {
            caps.append(.climateFanMode(fm))
        }
        if let fms = attrs.fanModes, !fms.isEmpty {
            caps.append(.climateFanModes(fms))
        }

        return caps
    }

    private static func mediaPlayerCapabilities(_ entity: HAEntityState) -> [Capability] {
        var caps: [Capability] = []
        let attrs = entity.attributes

        // Power — media players use "off" state
        caps.append(.power(isOn: entity.state != "off" && entity.state != "unavailable"))

        // Playback state
        let playback: PlaybackState = switch entity.state {
        case "playing": .playing
        case "paused": .paused
        case "idle", "off": .stopped
        case "buffering": .transitioning
        default: .unknown
        }
        caps.append(.playback(state: playback))

        // Volume (HA: 0.0-1.0 → our 0-100)
        if let vol = attrs.volumeLevel {
            caps.append(.volume(percent: Int(vol * 100.0)))
        }

        if let muted = attrs.isVolumeMuted {
            caps.append(.mute(isMuted: muted))
        }

        // Now playing metadata
        if attrs.mediaTitle != nil || attrs.mediaArtist != nil {
            var coverURL: URL?
            if let pic = attrs.entityPicture {
                // HA entity pictures are often relative paths — resolved
                // to absolute in HomeAssistantProvider.rebuildAccessory()
                // by prepending the server base URL. Here we just store
                // whatever URL we can parse; the provider fixes it later.
                coverURL = URL(string: pic)
            }
            caps.append(.nowPlaying(NowPlaying(
                title: attrs.mediaTitle,
                artist: attrs.mediaArtist,
                album: attrs.mediaAlbum,
                coverArtURL: coverURL,
                source: attrs.source
            )))
        }

        if let shuffle = attrs.shuffle {
            caps.append(.shuffle(isOn: shuffle))
        }

        if let rep = attrs.repeat {
            let mode: RepeatMode = switch rep {
            case "all": .all
            case "one": .one
            default: .off
            }
            caps.append(.repeatMode(mode))
        }

        // Source / input selection
        if let src = attrs.source {
            caps.append(.currentSource(src))
        }
        if let srcList = attrs.sourceList, !srcList.isEmpty {
            caps.append(.sourceList(srcList))
        }

        // Media position / duration
        if let pos = attrs.mediaPosition {
            caps.append(.mediaPosition(seconds: pos))
        }
        if let dur = attrs.mediaDuration {
            caps.append(.mediaDuration(seconds: dur))
        }

        return caps
    }

    private static func sensorCapabilities(_ entity: HAEntityState) -> [Capability] {
        var caps: [Capability] = []
        let attrs = entity.attributes

        switch attrs.deviceClass {
        case "temperature":
            if let val = Double(entity.state) {
                caps.append(.currentTemperature(celsius: val))
            }
        case "humidity":
            // Guard against "unavailable"/"unknown" — only parse real numbers
            if let d = Double(entity.state) {
                caps.append(.humidity(percent: Int(d.rounded())))
            }
        case "battery":
            if let d = Double(entity.state) {
                caps.append(.batteryLevel(percent: Int(d.rounded())))
            }
        default:
            break
        }

        return caps
    }

    private static func binarySensorCapabilities(_ entity: HAEntityState) -> [Capability] {
        let isOn = entity.state == "on"
        let attrs = entity.attributes

        switch attrs.deviceClass {
        case "motion", "occupancy", "presence":
            return [.motionSensor(isDetected: isOn)]
        case "door", "window", "garage_door", "opening":
            return [.contactSensor(isOpen: isOn)]
        case "smoke":
            return [.smokeDetected(isOn)]
        case "carbon_monoxide", "co":
            return [.coDetected(isOn)]
        default:
            return []
        }
    }

    private static func cameraCapabilities(_ entity: HAEntityState) -> [Capability] {
        // Cameras don't map to simple capabilities — they're handled
        // at the view layer via the REST client's camera proxy URL.
        [.power(isOn: entity.state != "unavailable")]
    }

    private static func fanCapabilities(_ entity: HAEntityState) -> [Capability] {
        var caps: [Capability] = [.power(isOn: entity.state == "on")]
        let attrs = entity.attributes

        if let pct = attrs.percentage {
            caps.append(.fanSpeed(percent: pct))
        }
        if let dir = attrs.direction {
            caps.append(.fanDirection(dir))
        }

        return caps
    }

    private static func coverCapabilities(_ entity: HAEntityState) -> [Capability] {
        var caps: [Capability] = [.power(isOn: entity.state == "open")]

        if let pos = entity.attributes.currentPosition {
            caps.append(.coverPosition(percent: pos))
        }

        return caps
    }

    private static func lockCapabilities(_ entity: HAEntityState) -> [Capability] {
        [.power(isOn: entity.state == "locked")]
    }

    private static func genericCapabilities(_ entity: HAEntityState) -> [Capability] {
        if entity.state == "on" || entity.state == "off" {
            return [.power(isOn: entity.state == "on")]
        }
        return []
    }
}
