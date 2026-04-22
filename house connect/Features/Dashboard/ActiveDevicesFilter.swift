//
//  ActiveDevicesFilter.swift
//  house connect
//
//  Pure-function predicates behind `T3HomeActiveDevicesSection`.
//  Extracted so they can be unit-tested without mounting SwiftUI
//  or wiring a ProviderRegistry. Every function takes an accessory
//  list, returns a filtered-and-sorted accessory list — no
//  observation, no actor isolation required.
//
//  Spec: docs/designs/2026-04-22-home-active-devices-design.md
//

import Foundation

enum ActiveDevicesFilter {
    /// Lights currently on. Unreachable devices excluded — a stale
    /// "on" state on a disconnected bulb is worse than nothing.
    nonisolated static func lightsOn(_ accessories: [Accessory]) -> [Accessory] {
        accessories
            .filter { $0.category == .light && $0.isReachable && $0.isOn == true }
            .sorted { $0.name < $1.name }
    }

    /// Media devices currently playing. Speaker / television / appleTV.
    /// When the device reports `playbackState`, "playing" means the
    /// state equals `.playing`. When it doesn't (some cheaper media
    /// players only report power), fall back to `isOn == true`.
    nonisolated static func nowPlaying(_ accessories: [Accessory]) -> [Accessory] {
        let mediaCategories: Set<Accessory.Category> = [.speaker, .television, .appleTV]
        return accessories
            .filter { acc in
                guard mediaCategories.contains(acc.category), acc.isReachable else { return false }
                if let state = acc.playbackState { return state == .playing }
                return acc.isOn == true
            }
            .sorted { $0.name < $1.name }
    }

    /// Thermostats whose HVAC mode is not `.off`. A thermostat set
    /// to heat or cool or auto counts as "active" even if it's
    /// currently idle (heat set but room already warm).
    nonisolated static func climateActive(_ accessories: [Accessory]) -> [Accessory] {
        accessories
            .filter { acc in
                guard acc.category == .thermostat, acc.isReachable else { return false }
                guard let mode = acc.hvacMode else { return false }
                return mode != .off
            }
            .sorted { $0.name < $1.name }
    }
}
