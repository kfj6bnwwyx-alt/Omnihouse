//
//  SmartThingsDTOs.swift
//  house connect
//
//  Codable mirrors of the SmartThings REST API shapes we care about. These
//  are DTOs — they exist only to decode JSON. Mapping into our unified
//  `Accessory` / `Room` / `Home` vocabulary happens in
//  SmartThingsCapabilityMapper, NOT here.
//
//  API reference:
//    https://developer.smartthings.com/docs/api/public
//
//  Relevant endpoints:
//    GET  /v1/locations                              → list locations
//    GET  /v1/locations/{locationId}/rooms           → rooms in a location
//    GET  /v1/devices                                → all devices (flat)
//    GET  /v1/devices/{deviceId}/status              → component/capability/attribute tree
//    POST /v1/devices/{deviceId}/commands            → execute a capability command
//
//  We intentionally keep most fields optional; SmartThings is pretty loose
//  about which keys are present and we'd rather shrug off a missing field
//  than fail to decode an entire device list.
//

import Foundation

enum SmartThingsDTO {

    // MARK: - Locations

    struct LocationsResponse: Decodable {
        let items: [Location]
    }

    struct Location: Decodable, Identifiable {
        let locationId: String
        let name: String
        var id: String { locationId }
    }

    // MARK: - Rooms

    struct RoomsResponse: Decodable {
        let items: [Room]
    }

    struct Room: Decodable, Identifiable {
        let roomId: String
        let name: String
        let locationId: String?
        var id: String { roomId }
    }

    // MARK: - Devices

    struct DevicesResponse: Decodable {
        let items: [Device]
    }

    struct Device: Decodable, Identifiable {
        let deviceId: String
        let name: String?
        let label: String?
        let locationId: String?
        let roomId: String?
        let deviceTypeName: String?
        let components: [Component]?

        var id: String { deviceId }

        /// User-facing display name. `label` is what the user set in the
        /// SmartThings app; fall back to `name` if they never renamed it.
        var displayName: String {
            label?.nonEmpty ?? name?.nonEmpty ?? "Unnamed device"
        }
    }

    struct Component: Decodable {
        let id: String
        let capabilities: [Capability]
    }

    struct Capability: Decodable {
        let id: String
        let version: Int?
    }

    // MARK: - Device status (attribute tree)
    //
    // Shape:
    //   {
    //     "components": {
    //       "main": {
    //         "switch": { "switch": { "value": "on" } },
    //         "switchLevel": { "level": { "value": 73 } },
    //         ...
    //       }
    //     }
    //   }
    //
    // We decode it as nested dictionaries because the keys are dynamic
    // (capability names + attribute names) and we don't want a giant
    // `CodingKeys` enum that has to know every capability in the catalog.

    struct DeviceStatus: Decodable {
        let components: [String: [String: [String: AttributeValue]]]

        /// Looks up an attribute on the "main" component, which is the
        /// component 99% of simple devices use.
        func mainAttribute(capability: String, attribute: String) -> AttributeValue? {
            components["main"]?[capability]?[attribute]
        }
    }

    /// SmartThings attribute values can be string / number / bool / null.
    /// Decoded as an enum so the mapper can pattern-match.
    enum AttributeValue: Decodable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case null

        enum CodingKeys: String, CodingKey {
            case value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.value) == false {
                self = .null
                return
            }
            if let b = try? container.decode(Bool.self, forKey: .value) {
                self = .bool(b); return
            }
            if let i = try? container.decode(Int.self, forKey: .value) {
                self = .int(i); return
            }
            if let d = try? container.decode(Double.self, forKey: .value) {
                self = .double(d); return
            }
            if let s = try? container.decode(String.self, forKey: .value) {
                self = .string(s); return
            }
            self = .null
        }

        var asBool: Bool? {
            switch self {
            case .bool(let b): return b
            case .string(let s): return s == "on" ? true : (s == "off" ? false : nil)
            default: return nil
            }
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
            case .string(let s): return Int(s)
            default: return nil
            }
        }

        var asString: String? {
            if case .string(let s) = self { return s }
            return nil
        }
    }

    // MARK: - Mutations (device label, rooms)

    /// PATCH-style body for PUT /v1/devices/{id}.
    /// Only `label` is writable via this endpoint; everything else is
    /// derived from the hub's understanding of the device.
    struct DeviceLabelUpdate: Encodable {
        let label: String
    }

    /// Body for POST /v1/locations/{locationId}/rooms.
    struct CreateRoomRequest: Encodable {
        let name: String
    }

    /// Body for PUT /v1/locations/{locationId}/rooms/{roomId}.
    /// SmartThings accepts the same shape for creation and update.
    struct UpdateRoomRequest: Encodable {
        let name: String
    }

    /// Body for PUT /v1/devices/{id} when moving a device between rooms.
    /// SmartThings requires passing the owning `locationId` alongside the
    /// target `roomId`.
    struct DeviceRoomUpdate: Encodable {
        let roomId: String?
        let locationId: String
    }

    // MARK: - Commands

    /// POST body for /v1/devices/{id}/commands.
    /// SmartThings expects: `{ "commands": [ { component, capability, command, arguments } ] }`
    struct CommandEnvelope: Encodable {
        let commands: [Command]
    }

    struct Command: Encodable {
        let component: String
        let capability: String
        let command: String
        let arguments: [CommandArgument]

        init(component: String = "main",
             capability: String,
             command: String,
             arguments: [CommandArgument] = []) {
            self.component = component
            self.capability = capability
            self.command = command
            self.arguments = arguments
        }
    }

    /// Arguments in the SmartThings wire format are heterogeneous, so we wrap
    /// them in an enum that encodes to the right JSON primitive.
    enum CommandArgument: Encodable {
        case int(Int)
        case double(Double)
        case string(String)
        case bool(Bool)

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .int(let i): try c.encode(i)
            case .double(let d): try c.encode(d)
            case .string(let s): try c.encode(s)
            case .bool(let b): try c.encode(b)
            }
        }
    }

    // MARK: - Errors

    struct ErrorEnvelope: Decodable {
        let requestId: String?
        let error: ErrorBody?

        struct ErrorBody: Decodable {
            let code: String?
            let message: String?
        }
    }
}

// MARK: - Helpers

private extension String {
    /// Returns `nil` if the string is empty after trimming. Useful for
    /// coalescing SmartThings' empty-string-vs-null inconsistency.
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
