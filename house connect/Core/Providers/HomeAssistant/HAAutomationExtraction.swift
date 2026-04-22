//
//  HAAutomationExtraction.swift
//  house connect
//
//  Pulls the bits a UI needs out of an `HAAutomationConfig`:
//    · every referenced entity_id (so detail views can filter)
//    · a one-line trigger summary ("WHEN sun sets")
//    · a one-line action summary ("TURN ON light.kitchen")
//
//  Home Assistant's automation YAML is wildly heterogeneous across
//  integrations — we extract the common shapes and fall back to a
//  generic label for anything we don't recognise. Missing data is
//  always nil/empty, never synthesised.
//

import Foundation

enum HAAutomationExtraction {

    /// Every entity_id referenced anywhere in an automation config's
    /// triggers, conditions, or actions. Traverses the whole JSON
    /// blob recursively picking up any "entity_id" key (string or
    /// array of strings).
    static func referencedEntityIDs(in config: HAAutomationConfig) -> Set<String> {
        var ids: Set<String> = []
        collect(value: .array(config.trigger ?? []), into: &ids)
        collect(value: .array(config.condition ?? []), into: &ids)
        collect(value: .array(config.action ?? []), into: &ids)
        return ids
    }

    /// Human-readable summary of the first trigger, or nil if none.
    /// Examples: "WHEN sun sets", "WHEN motion.hall", "WHEN 18:00".
    static func triggerSummary(for config: HAAutomationConfig) -> String? {
        guard let first = config.trigger?.first?.dictValue else { return nil }
        let platform = first["platform"]?.stringValue ?? first["trigger"]?.stringValue
        switch platform {
        case "state":
            if let entity = firstEntityID(in: first) {
                return "WHEN \(entity) CHANGES"
            }
        case "time":
            if let at = first["at"]?.stringValue { return "WHEN \(at)" }
        case "time_pattern":
            return "WHEN TIME MATCHES"
        case "sun":
            let event = first["event"]?.stringValue ?? "event"
            return "WHEN SUN \(event.uppercased())"
        case "numeric_state":
            if let entity = firstEntityID(in: first) {
                return "WHEN \(entity) CROSSES THRESHOLD"
            }
        case "device":
            if let entity = firstEntityID(in: first) {
                return "WHEN \(entity)"
            }
            return "WHEN DEVICE EVENT"
        case "event":
            let type = first["event_type"]?.stringValue ?? "event"
            return "WHEN EVENT \(type.uppercased())"
        case "webhook": return "WHEN WEBHOOK"
        case "zone":
            let event = first["event"]?.stringValue ?? "event"
            return "WHEN ZONE \(event.uppercased())"
        case "template": return "WHEN TEMPLATE MATCHES"
        default: break
        }
        if let platform { return "WHEN \(platform.uppercased())" }
        return nil
    }

    /// Human-readable summary of the first action, or nil if none.
    /// Examples: "TURN ON light.kitchen", "CALL scene.movie_night".
    static func actionSummary(for config: HAAutomationConfig) -> String? {
        guard let first = config.action?.first?.dictValue else { return nil }
        // Service call — most common action type.
        if let service = first["service"]?.stringValue
            ?? first["action"]?.stringValue {
            let target = firstEntityID(in: first)
                ?? (first["target"]?.dictValue).flatMap(firstEntityID(in:))
                ?? (first["data"]?.dictValue).flatMap(firstEntityID(in:))
            let verb = prettyServiceVerb(service)
            if let target {
                return "\(verb) \(target)"
            }
            return verb
        }
        // Delay / wait_template / choose / repeat — show the type.
        for key in ["delay", "wait_template", "choose", "repeat", "if", "parallel"] {
            if first[key] != nil {
                return key.uppercased()
            }
        }
        return nil
    }

    // MARK: - Private

    /// Recursively walks `value` and appends any entity_id strings
    /// found under the conventional "entity_id" key (value can be a
    /// string or an array of strings in HA configs).
    private static func collect(value: AnyCodableValue, into ids: inout Set<String>) {
        switch value {
        case .dictionary(let dict):
            if let direct = dict["entity_id"] {
                switch direct {
                case .string(let s): ids.insert(s)
                case .array(let arr):
                    for item in arr {
                        if case .string(let s) = item { ids.insert(s) }
                    }
                default: break
                }
            }
            for (_, sub) in dict { collect(value: sub, into: &ids) }
        case .array(let arr):
            for item in arr { collect(value: item, into: &ids) }
        default: break
        }
    }

    private static func firstEntityID(in dict: [String: AnyCodableValue]) -> String? {
        if case .string(let s) = dict["entity_id"] { return s }
        if case .array(let arr) = dict["entity_id"] {
            for item in arr { if case .string(let s) = item { return s } }
        }
        return nil
    }

    /// Map common HA service names to plain-verb labels. Anything
    /// unrecognised falls back to "CALL <service>" so the user still
    /// sees what's happening.
    private static func prettyServiceVerb(_ service: String) -> String {
        // Services are "domain.service" e.g. "light.turn_on".
        let parts = service.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return "CALL \(service.uppercased())" }
        let method = parts[1]
        switch method {
        case "turn_on":     return "TURN ON"
        case "turn_off":    return "TURN OFF"
        case "toggle":      return "TOGGLE"
        case "lock":        return "LOCK"
        case "unlock":      return "UNLOCK"
        case "open_cover":  return "OPEN"
        case "close_cover": return "CLOSE"
        case "press":       return "PRESS"
        case "trigger":     return "TRIGGER"
        case "set_temperature": return "SET TEMP"
        case "start":       return "START"
        case "stop":        return "STOP"
        default: return "CALL \(service.uppercased())"
        }
    }
}
