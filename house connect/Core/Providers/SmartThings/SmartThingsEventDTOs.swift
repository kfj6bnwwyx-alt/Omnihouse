//
//  SmartThingsEventDTOs.swift
//  house connect
//
//  Codable types for SmartThings Server-Sent Events (SSE). The SSE
//  endpoint at `https://api.smartthings.com/v1/sse/devices` pushes
//  real-time device state changes as JSON payloads.
//
//  Event shape:
//    event: DEVICE_EVENT
//    data: {"eventId":"...","deviceId":"...","componentId":"main",
//           "capability":"switch","attribute":"switch",
//           "value":"on","stateChange":true}
//

import Foundation

/// A single device state-change event from the SmartThings SSE stream.
struct SmartThingsDeviceEvent: Sendable {
    let eventId: String?
    let deviceId: String
    let componentId: String
    let capability: String
    let attribute: String
    let value: SSEValue
    let stateChange: Bool?
}

extension SmartThingsDeviceEvent: Decodable {
    enum CodingKeys: String, CodingKey {
        case eventId, deviceId, componentId, capability, attribute, value, stateChange
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try c.decodeIfPresent(String.self, forKey: .eventId)
        deviceId = try c.decode(String.self, forKey: .deviceId)
        componentId = try c.decodeIfPresent(String.self, forKey: .componentId) ?? "main"
        capability = try c.decode(String.self, forKey: .capability)
        attribute = try c.decode(String.self, forKey: .attribute)
        value = try c.decode(SSEValue.self, forKey: .value)
        stateChange = try c.decodeIfPresent(Bool.self, forKey: .stateChange)
    }
}

/// Flexible JSON value for SSE event payloads. SSE values are bare
/// primitives at the top level (not wrapped in `{"value": ...}` like
/// the REST API's AttributeValue).
struct SSEValue: Decodable, Sendable {
    let inner: SmartThingsDTO.AttributeValue

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { inner = .bool(b); return }
        if let i = try? c.decode(Int.self) { inner = .int(i); return }
        if let d = try? c.decode(Double.self) { inner = .double(d); return }
        if let s = try? c.decode(String.self) { inner = .string(s); return }
        inner = .null
    }
}
