//
//  NestSDMDTOs.swift
//  house connect
//
//  Codable mirrors of the Google Smart Device Management (SDM) REST API
//  response shapes. These are DTOs — they exist only to decode JSON from
//  https://smartdevicemanagement.googleapis.com/v1/. Mapping into our
//  unified vocabulary happens in NestCapabilityMapper.
//
//  API reference:
//    https://developers.google.com/nest/device-access/api
//
//  SDM device types we handle:
//    sdm.devices.types.THERMOSTAT
//    sdm.devices.types.CAMERA
//    sdm.devices.types.DOORBELL
//    sdm.devices.types.DISPLAY
//
//  NOTE: Nest Protect (smoke/CO) is NOT in the SDM program. Google
//  removed it from Device Access entirely. The `.smokeAlarm` category
//  and `smokeDetected`/`coDetected` capabilities exist for the demo
//  provider only.
//

import Foundation

enum NestSDMDTO {

    // MARK: - Devices

    struct DevicesResponse: Decodable {
        let devices: [Device]
    }

    struct Device: Decodable, Identifiable {
        /// Full resource path, e.g. "enterprises/{id}/devices/{id}"
        let name: String
        /// SDM device type, e.g. "sdm.devices.types.THERMOSTAT"
        let type: String
        /// Trait payloads keyed by trait name.
        let traits: [String: TraitPayload]
        /// Parent relation links this device to a structure/room.
        let parentRelations: [ParentRelation]?

        var id: String { deviceID }

        /// Extracts the device ID from the full resource path.
        var deviceID: String {
            name.components(separatedBy: "/").last ?? name
        }

        /// Reads a trait by its full SDM name (e.g. "sdm.devices.traits.Temperature").
        func trait(_ name: String) -> TraitPayload? {
            traits[name]
        }
    }

    struct ParentRelation: Decodable {
        /// Resource name of the parent (structure or room).
        let parent: String
        /// User-assigned display name for the room.
        let displayName: String?
    }

    // MARK: - Trait payload

    /// SDM trait values are heterogeneous JSON objects. We decode them
    /// as dictionaries of flexible values rather than trying to model
    /// every trait as a dedicated struct — keeps the DTO layer thin
    /// and lets the mapper cherry-pick what it needs.
    struct TraitPayload: Decodable {
        let values: [String: AnyCodableValue]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            values = try container.decode([String: AnyCodableValue].self)
        }

        init(values: [String: AnyCodableValue]) {
            self.values = values
        }

        func string(_ key: String) -> String? { values[key]?.asString }
        func double(_ key: String) -> Double? { values[key]?.asDouble }
        func int(_ key: String) -> Int? { values[key]?.asInt }
        func bool(_ key: String) -> Bool? { values[key]?.asBool }
    }

    /// Flexible JSON value — mirrors SmartThingsDTO.AttributeValue but
    /// without the `{ "value": ... }` nesting since SDM traits use
    /// flat key-value objects.
    enum AnyCodableValue: Codable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let b = try? c.decode(Bool.self) { self = .bool(b); return }
            if let i = try? c.decode(Int.self) { self = .int(i); return }
            if let d = try? c.decode(Double.self) { self = .double(d); return }
            if let s = try? c.decode(String.self) { self = .string(s); return }
            self = .null
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .string(let v): try c.encode(v)
            case .int(let v): try c.encode(v)
            case .double(let v): try c.encode(v)
            case .bool(let v): try c.encode(v)
            case .null: try c.encodeNil()
            }
        }

        var asString: String? {
            if case .string(let s) = self { return s }
            return nil
        }

        var asDouble: Double? {
            switch self {
            case .double(let d): return d
            case .int(let i): return Double(i)
            case .string(let s): return Double(s)
            default: return nil
            }
        }

        var asInt: Int? {
            switch self {
            case .int(let i): return i
            case .double(let d): return Int(d)
            default: return nil
            }
        }

        var asBool: Bool? {
            if case .bool(let b) = self { return b }
            return nil
        }
    }

    // MARK: - Structures (homes)

    struct StructuresResponse: Decodable {
        let structures: [Structure]
    }

    struct Structure: Decodable, Identifiable {
        let name: String  // resource path
        let traits: [String: TraitPayload]?

        var id: String { name.components(separatedBy: "/").last ?? name }

        /// Display name from the Info trait.
        var displayName: String {
            traits?["sdm.structures.traits.Info"]?.string("customName")
                ?? "Nest Home"
        }
    }

    // MARK: - Rooms

    struct RoomsResponse: Decodable {
        let rooms: [SDMRoom]
    }

    struct SDMRoom: Decodable, Identifiable {
        let name: String  // resource path
        let traits: [String: TraitPayload]?

        var id: String { name.components(separatedBy: "/").last ?? name }

        var displayName: String {
            traits?["sdm.structures.traits.RoomInfo"]?.string("customName")
                ?? "Room"
        }
    }

    // MARK: - Commands

    /// POST body for executeCommand.
    struct CommandRequest: Encodable {
        let command: String
        let params: [String: AnyCodableValue]?
    }

    // MARK: - OAuth Token Response

    struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: Int
        let refreshToken: String?
        let tokenType: String
        let scope: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case scope
        }
    }
}
