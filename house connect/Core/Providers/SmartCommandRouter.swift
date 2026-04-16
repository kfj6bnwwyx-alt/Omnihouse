//
//  SmartCommandRouter.swift
//  house connect
//
//  Per-command routing for merged (dual-homed) devices. When the same
//  physical device is published by multiple providers (e.g. a Hue bulb
//  visible via HomeKit AND SmartThings), this router picks the BEST
//  provider for each specific command — preferring local-network
//  (HomeKit) for latency-sensitive actions, falling back to cloud
//  providers when local is unreachable, and skipping providers that
//  don't support the command at all.
//
//  Design:
//  -------
//  Pure, stateless, testable. No side effects, no stored state. The
//  caller (ProviderRegistry) invokes `bestTargets(...)` and iterates
//  the result, trying each provider in order until one succeeds.
//
//  Priority order (per command):
//    1. Providers that support the command's capability kind
//    2. Among those, prefer reachable over unreachable
//    3. Among reachable, prefer the user's chosen provider
//    4. Among equally-preferred, prefer HomeKit (local network = lowest latency)
//

import Foundation

enum SmartCommandRouter {

    /// Returns an ordered list of AccessoryIDs to try for a given command,
    /// best-first. The caller should iterate and stop on first success.
    /// Returns empty if no provider supports the command.
    static func bestTargets(
        for command: AccessoryCommand,
        capabilityProviders: [Capability.Kind: [AccessoryID]],
        reachableIDs: Set<AccessoryID>,
        preferredProvider: ProviderID
    ) -> [AccessoryID] {
        // Map the command to the capability kind it targets.
        guard let kind = capabilityKind(for: command) else {
            // Commands that don't map to a specific capability (play, pause,
            // etc.) can be sent to any provider. Return all reachable, sorted
            // by preference.
            let allIDs = capabilityProviders.values.flatMap { $0 }
            let unique = Array(Set(allIDs))
            return sorted(unique, reachableIDs: reachableIDs, preferredProvider: preferredProvider)
        }

        guard let candidates = capabilityProviders[kind], !candidates.isEmpty else {
            return []
        }

        return sorted(candidates, reachableIDs: reachableIDs, preferredProvider: preferredProvider)
    }

    // MARK: - Command → Capability kind mapping

    /// Maps an AccessoryCommand to the Capability.Kind it reads/writes.
    /// Returns nil for transport commands (play/pause/stop/next/prev)
    /// since those don't correspond to a stored capability — any provider
    /// that has the device can attempt them.
    static func capabilityKind(for command: AccessoryCommand) -> Capability.Kind? {
        switch command {
        case .setPower:                return .power
        case .setBrightness:           return .brightness
        case .setHue:                  return .hue
        case .setSaturation:           return .saturation
        case .setColorTemperature:     return .colorTemperature
        case .setTargetTemperature:    return .targetTemperature
        case .setHVACMode:             return .hvacMode
        case .setVolume:               return .volume
        case .setGroupVolume:          return .volume
        case .setMute:                 return .mute
        case .setShuffle:              return .shuffle
        case .setRepeatMode:           return .repeatMode
        case .selfTest:                return nil
        case .play, .pause, .stop,
             .next, .previous:         return nil
        case .joinSpeakerGroup,
             .leaveSpeakerGroup:       return nil
        case .selectSource:            return .currentSource
        case .setPresetMode:           return .presetMode
        case .setClimateFanMode:       return .climateFanMode
        case .setFanSpeed:             return .fanSpeed
        case .setFanDirection:         return .fanDirection
        case .setCoverPosition:        return .coverPosition
        case .playMedia:               return nil
        case .seekTo:                  return .mediaPosition
        case .setEffect:               return .currentEffect
        }
    }

    // MARK: - Sorting

    /// Sorts candidates: reachable before unreachable, preferred provider
    /// first among reachable, HomeKit preferred for latency tie-break.
    private static func sorted(
        _ ids: [AccessoryID],
        reachableIDs: Set<AccessoryID>,
        preferredProvider: ProviderID
    ) -> [AccessoryID] {
        ids.sorted { a, b in
            let aReach = reachableIDs.contains(a)
            let bReach = reachableIDs.contains(b)
            // Reachable always before unreachable
            if aReach != bReach { return aReach }
            // Preferred provider first among equal reachability
            if a.provider != b.provider {
                if a.provider == preferredProvider { return true }
                if b.provider == preferredProvider { return false }
                // HomeKit (local) tie-break
                if a.provider == .homeKit { return true }
                if b.provider == .homeKit { return false }
            }
            return false
        }
    }
}
