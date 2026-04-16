//
//  HomeAssistantDTOs.swift
//  house connect
//
//  Codable models for the Home Assistant REST + WebSocket APIs.
//  These are wire-format mirrors — the capability mapper is the
//  only thing that translates them into our domain model.
//

import Foundation

// MARK: - Entity State (the fundamental HA unit)

/// A single HA entity's state snapshot, as returned by GET /api/states
/// or via the WebSocket `get_states` / `state_changed` events.
struct HAEntityState: Codable, Sendable, Identifiable {
    let entityID: String
    let state: String
    let lastChanged: String?
    let lastUpdated: String?
    let attributes: HAAttributes

    var id: String { entityID }

    /// The domain prefix (e.g. "light", "climate", "media_player").
    var domain: String {
        entityID.components(separatedBy: ".").first ?? ""
    }

    /// The object_id suffix after the domain dot.
    var objectID: String {
        let parts = entityID.components(separatedBy: ".")
        return parts.count > 1 ? parts.dropFirst().joined(separator: ".") : entityID
    }

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case state
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
        case attributes
    }
}

/// Loosely-typed attributes dictionary. HA entities have wildly varying
/// attribute sets per domain, so we decode the known keys and leave
/// the rest accessible via the raw dictionary.
struct HAAttributes: Codable, Sendable {
    let friendlyName: String?
    let deviceClass: String?
    let unitOfMeasurement: String?
    let icon: String?

    // Light
    let brightness: Int?             // 0-255
    let colorTempKelvin: Int?
    let minColorTempKelvin: Int?
    let maxColorTempKelvin: Int?
    let hsColor: [Double]?           // [hue 0-360, saturation 0-100]
    let rgbColor: [Int]?             // [r, g, b]
    let colorMode: String?
    let supportedColorModes: [String]?

    // Climate
    let temperature: Double?         // target temp
    let currentTemperature: Double?
    let targetTempHigh: Double?
    let targetTempLow: Double?
    let hvacAction: String?          // "heating", "cooling", "idle", "off"
    let hvacModes: [String]?
    let fanMode: String?
    let fanModes: [String]?
    let presetMode: String?
    let presetModes: [String]?
    let minTemp: Double?
    let maxTemp: Double?

    // Media player
    let volumeLevel: Double?         // 0.0-1.0
    let isVolumeMuted: Bool?
    let mediaTitle: String?
    let mediaArtist: String?
    let mediaAlbum: String?
    let mediaContentType: String?
    let mediaDuration: Double?
    let mediaPosition: Double?
    let shuffle: Bool?
    let `repeat`: String?            // "off", "all", "one"
    let source: String?
    let sourceList: [String]?
    let soundMode: String?
    let soundModeList: [String]?
    let groupMembers: [String]?
    let entityPicture: String?

    // Light effects
    let effect: String?
    let effectList: [String]?

    // Fan
    let percentage: Int?             // 0-100 fan speed
    let direction: String?           // "forward" / "reverse"
    let presetModes2: [String]?      // fan preset modes (decoded from "preset_modes" when domain=fan)

    // Cover
    let currentPosition: Int?        // 0-100

    // Sensor / binary sensor
    let batteryLevel: Int?

    // Camera
    let accessToken: String?         // for camera proxy URL

    // Area / device (from entity registry)
    let areaID: String?
    let deviceID: String?

    // Catch-all for unknown attributes
    let raw: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case friendlyName = "friendly_name"
        case deviceClass = "device_class"
        case unitOfMeasurement = "unit_of_measurement"
        case icon
        case brightness
        case colorTempKelvin = "color_temp_kelvin"
        case minColorTempKelvin = "min_color_temp_kelvin"
        case maxColorTempKelvin = "max_color_temp_kelvin"
        case hsColor = "hs_color"
        case rgbColor = "rgb_color"
        case colorMode = "color_mode"
        case supportedColorModes = "supported_color_modes"
        case temperature
        case currentTemperature = "current_temperature"
        case targetTempHigh = "target_temp_high"
        case targetTempLow = "target_temp_low"
        case hvacAction = "hvac_action"
        case hvacModes = "hvac_modes"
        case fanMode = "fan_mode"
        case fanModes = "fan_modes"
        case presetMode = "preset_mode"
        case presetModes = "preset_modes"
        case minTemp = "min_temp"
        case maxTemp = "max_temp"
        case volumeLevel = "volume_level"
        case isVolumeMuted = "is_volume_muted"
        case mediaTitle = "media_title"
        case mediaArtist = "media_artist"
        case mediaAlbum = "media_album"
        case mediaContentType = "media_content_type"
        case mediaDuration = "media_duration"
        case mediaPosition = "media_position"
        case shuffle
        case `repeat`
        case source
        case sourceList = "source_list"
        case soundMode = "sound_mode"
        case soundModeList = "sound_mode_list"
        case groupMembers = "group_members"
        case entityPicture = "entity_picture"
        case effect
        case effectList = "effect_list"
        case percentage
        case direction
        case presetModes2  // unused key — fan preset_modes overlaps climate's, handled in init
        case currentPosition = "current_position"
        case batteryLevel = "battery_level"
        case accessToken = "access_token"
        case areaID = "area_id"
        case deviceID = "device_id"
        case raw
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        friendlyName = try c.decodeIfPresent(String.self, forKey: .friendlyName)
        deviceClass = try c.decodeIfPresent(String.self, forKey: .deviceClass)
        unitOfMeasurement = try c.decodeIfPresent(String.self, forKey: .unitOfMeasurement)
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        brightness = try c.decodeIfPresent(Int.self, forKey: .brightness)
        colorTempKelvin = try c.decodeIfPresent(Int.self, forKey: .colorTempKelvin)
        minColorTempKelvin = try c.decodeIfPresent(Int.self, forKey: .minColorTempKelvin)
        maxColorTempKelvin = try c.decodeIfPresent(Int.self, forKey: .maxColorTempKelvin)
        hsColor = try c.decodeIfPresent([Double].self, forKey: .hsColor)
        rgbColor = try c.decodeIfPresent([Int].self, forKey: .rgbColor)
        colorMode = try c.decodeIfPresent(String.self, forKey: .colorMode)
        supportedColorModes = try c.decodeIfPresent([String].self, forKey: .supportedColorModes)
        temperature = try c.decodeIfPresent(Double.self, forKey: .temperature)
        currentTemperature = try c.decodeIfPresent(Double.self, forKey: .currentTemperature)
        targetTempHigh = try c.decodeIfPresent(Double.self, forKey: .targetTempHigh)
        targetTempLow = try c.decodeIfPresent(Double.self, forKey: .targetTempLow)
        hvacAction = try c.decodeIfPresent(String.self, forKey: .hvacAction)
        hvacModes = try c.decodeIfPresent([String].self, forKey: .hvacModes)
        fanMode = try c.decodeIfPresent(String.self, forKey: .fanMode)
        fanModes = try c.decodeIfPresent([String].self, forKey: .fanModes)
        presetMode = try c.decodeIfPresent(String.self, forKey: .presetMode)
        presetModes = try c.decodeIfPresent([String].self, forKey: .presetModes)
        minTemp = try c.decodeIfPresent(Double.self, forKey: .minTemp)
        maxTemp = try c.decodeIfPresent(Double.self, forKey: .maxTemp)
        volumeLevel = try c.decodeIfPresent(Double.self, forKey: .volumeLevel)
        isVolumeMuted = try c.decodeIfPresent(Bool.self, forKey: .isVolumeMuted)
        mediaTitle = try c.decodeIfPresent(String.self, forKey: .mediaTitle)
        mediaArtist = try c.decodeIfPresent(String.self, forKey: .mediaArtist)
        mediaAlbum = try c.decodeIfPresent(String.self, forKey: .mediaAlbum)
        mediaContentType = try c.decodeIfPresent(String.self, forKey: .mediaContentType)
        mediaDuration = try c.decodeIfPresent(Double.self, forKey: .mediaDuration)
        mediaPosition = try c.decodeIfPresent(Double.self, forKey: .mediaPosition)
        shuffle = try c.decodeIfPresent(Bool.self, forKey: .shuffle)
        `repeat` = try c.decodeIfPresent(String.self, forKey: .repeat)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        sourceList = try c.decodeIfPresent([String].self, forKey: .sourceList)
        soundMode = try c.decodeIfPresent(String.self, forKey: .soundMode)
        soundModeList = try c.decodeIfPresent([String].self, forKey: .soundModeList)
        groupMembers = try c.decodeIfPresent([String].self, forKey: .groupMembers)
        entityPicture = try c.decodeIfPresent(String.self, forKey: .entityPicture)
        effect = try c.decodeIfPresent(String.self, forKey: .effect)
        effectList = try c.decodeIfPresent([String].self, forKey: .effectList)
        percentage = try c.decodeIfPresent(Int.self, forKey: .percentage)
        direction = try c.decodeIfPresent(String.self, forKey: .direction)
        presetModes2 = nil  // fan preset modes — use presetModes for climate
        currentPosition = try c.decodeIfPresent(Int.self, forKey: .currentPosition)
        batteryLevel = try c.decodeIfPresent(Int.self, forKey: .batteryLevel)
        accessToken = try c.decodeIfPresent(String.self, forKey: .accessToken)
        areaID = try c.decodeIfPresent(String.self, forKey: .areaID)
        deviceID = try c.decodeIfPresent(String.self, forKey: .deviceID)
        // Decode all remaining/unknown keys into the raw catch-all so
        // the mapper can access attributes not modeled as typed fields
        // (e.g. current_humidity on climate entities).
        let allKeys = try decoder.container(keyedBy: DynamicKey.self)
        var rawDict: [String: AnyCodableValue] = [:]
        let typedKeys = Set(CodingKeys.allCases.map(\.stringValue))
        for key in allKeys.allKeys where !typedKeys.contains(key.stringValue) {
            if let val = try? allKeys.decode(AnyCodableValue.self, forKey: key) {
                rawDict[key.stringValue] = val
            }
        }
        raw = rawDict.isEmpty ? nil : rawDict
    }

    /// Dynamic coding key for catch-all attribute decoding.
    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}

// MARK: - WebSocket Messages

/// Outbound WebSocket message envelope.
struct HAWebSocketCommand: Encodable, Sendable {
    let id: Int
    let type: String
    var eventType: String?
    var domain: String?
    var service: String?
    var serviceData: [String: AnyCodableValue]?
    var target: HAServiceTarget?

    enum CodingKeys: String, CodingKey {
        case id, type
        case eventType = "event_type"
        case domain, service
        case serviceData = "service_data"
        case target
    }
}

/// Target for a service call.
struct HAServiceTarget: Codable, Sendable {
    var entityID: [String]?
    var deviceID: [String]?
    var areaID: [String]?

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case deviceID = "device_id"
        case areaID = "area_id"
    }
}

/// Inbound WebSocket message. HA sends different shapes depending on
/// `type`, so we decode the common fields and leave event data as raw JSON.
struct HAWebSocketMessage: Codable, Sendable {
    let type: String
    let id: Int?
    let haVersion: String?
    let success: Bool?
    let result: AnyCodableValue?
    let event: HAEventPayload?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case type, id
        case haVersion = "ha_version"
        case success, result, event, message
    }
}

/// Event payload inside a WebSocket event message.
struct HAEventPayload: Codable, Sendable {
    let eventType: String?
    let data: HAEventData?
    let timeFired: String?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case data
        case timeFired = "time_fired"
    }
}

/// State-change event data.
struct HAEventData: Codable, Sendable {
    let entityID: String?
    let oldState: HAEntityState?
    let newState: HAEntityState?

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case oldState = "old_state"
        case newState = "new_state"
    }
}

// MARK: - Device & Area Registry (from entity_registry/list_for_display)

/// HA device registry entry.
struct HADevice: Codable, Sendable, Identifiable {
    let id: String
    let name: String?
    let manufacturer: String?
    let model: String?
    let areaID: String?
    let configEntries: [String]?
    let swVersion: String?

    enum CodingKeys: String, CodingKey {
        case id, name, manufacturer, model
        case areaID = "area_id"
        case configEntries = "config_entries"
        case swVersion = "sw_version"
    }
}

/// HA area registry entry (maps to our Room).
struct HAArea: Codable, Sendable, Identifiable {
    let id: String   // HA-generated slug, e.g. "living_room"
    let name: String
    let icon: String?
    let picture: String?

    enum CodingKeys: String, CodingKey {
        case id = "area_id"
        case name
        case icon
        case picture
    }
}

/// HA entity registry entry (compact display format).
struct HAEntityRegistryEntry: Codable, Sendable {
    let entityID: String
    let name: String?
    let platform: String?
    let areaID: String?
    let deviceID: String?
    let disabledBy: String?
    let hiddenBy: String?
    let entityCategory: String?

    enum CodingKeys: String, CodingKey {
        case entityID = "ei"
        case name = "en"
        case platform = "pl"
        case areaID = "ai"
        case deviceID = "di"
        case disabledBy = "db"
        case hiddenBy = "hb"
        case entityCategory = "ec"
    }
}

/// Wrapper for the entity registry display list response.
struct HAEntityRegistryDisplayResponse: Codable, Sendable {
    let entities: [HAEntityRegistryEntry]

    enum CodingKeys: String, CodingKey {
        case entities
    }
}

// MARK: - Config

struct HAConfig: Codable, Sendable {
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
    let unitSystem: HAUnitSystem?
    let version: String?
    let components: [String]?

    enum CodingKeys: String, CodingKey {
        case locationName = "location_name"
        case latitude, longitude
        case unitSystem = "unit_system"
        case version, components
    }
}

struct HAUnitSystem: Codable, Sendable {
    let temperature: String?  // "°C" or "°F"
    let length: String?
    let mass: String?
    let volume: String?
}

// MARK: - Scene / Automation entities

struct HAScene: Identifiable, Sendable {
    let entityID: String
    let name: String
    let lastActivated: String?

    var id: String { entityID }
}

// MARK: - AnyCodableValue (heterogeneous JSON helper)

/// Minimal type-erased Codable wrapper for HA's loosely-typed JSON.
/// Handles the common value types HA sends: strings, numbers, bools,
/// arrays, and nested dictionaries.
enum AnyCodableValue: Codable, Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([AnyCodableValue].self) {
            self = .array(arr)
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dict)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .dictionary(let d): try container.encode(d)
        case .null: try container.encodeNil()
        }
    }
}
