//
//  DeviceDetailView.swift
//  house connect
//
//  Router that dispatches an `AccessoryID` to the correct per-category
//  detail screen. The Pencil design ships bespoke layouts for Sonos,
//  thermostats, cameras, smoke alarms, and the Samsung Frame TV — the
//  generic `AccessoryDetailView` is the fallback for every category we
//  haven't drawn yet (lights, switches, outlets, locks, sensors, fans,
//  blinds, …).
//
//  Dispatch order:
//    1. If the live accessory is unreachable, show `DeviceOfflineView`.
//    2. Else pick a bespoke view based on `Accessory.Category` (and in a
//       couple of cases the provider, because a Sonos speaker and a
//       generic AirPlay "speaker" get very different screens).
//    3. Else fall through to `AccessoryDetailView`.
//
//  Every detail view receives the `AccessoryID`, NOT the `Accessory`
//  snapshot. That way pushing a detail screen while the provider is
//  still refreshing keeps the view live instead of freezing on a stale
//  copy of the device.
//

import SwiftUI

struct DeviceDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    /// Live look-up so the router re-evaluates as the underlying provider
    /// emits refreshed state. If the accessory is removed (pairing lost,
    /// provider disconnected) we surface a ContentUnavailableView.
    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    var body: some View {
        Group {
            if let accessory {
                if !accessory.isReachable {
                    DeviceOfflineView(accessoryID: accessoryID)
                } else {
                    routedView(for: accessory)
                }
            } else {
                ContentUnavailableView(
                    "Accessory unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This device is no longer reported by its provider.")
                )
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Dispatch

    @ViewBuilder
    private func routedView(for accessory: Accessory) -> some View {
        switch accessory.category {
        case .speaker:
            // Bespoke Sonos player for Sonos; bonded sets (home theater
            // surround, stereo pair) get a dedicated first-class screen
            // that lists the bonded parts as "Group Members". Generic
            // fallback for any other speaker surface (AirPlay,
            // SmartThings, etc.) until we draw those separately.
            if accessory.id.provider == .sonos {
                if let parts = accessory.groupedParts, parts.count > 1 {
                    SonosBondedGroupDetailView(accessoryID: accessoryID)
                } else {
                    SonosPlayerDetailView(accessoryID: accessoryID)
                }
            } else {
                AccessoryDetailView(accessoryID: accessoryID)
            }

        case .thermostat:
            ThermostatDetailView(accessoryID: accessoryID)

        case .camera:
            CameraDetailView(accessoryID: accessoryID)

        case .smokeAlarm:
            // Dedicated smoke/CO alarm detail (Pencil `mATCa`). Nest
            // Protect and similar devices route here via the `.smokeAlarm`
            // category, which is distinct from generic `.sensor`.
            SmokeAlarmDetailView(accessoryID: accessoryID)

        case .sensor:
            // Generic sensor — motion, contact, temperature, etc.
            AccessoryDetailView(accessoryID: accessoryID)

        case .light:
            // Bespoke lighting screen (Pencil node `kNqSI`). Bars-based
            // brightness visualizer, color-temp gradient, quick presets,
            // schedule card. Lights are the single largest device category
            // in a typical home and the generic form-based detail screen
            // felt flat for them, so they get first-class real estate.
            LightControlView(accessoryID: accessoryID)

        case .television:
            // Bespoke Samsung Frame TV screen (Pencil `GrzJY`). Routes
            // here when a provider tags an accessory as a TV — today
            // that's SmartThings via Frame-specific capability IDs; a
            // native Samsung Frame TV provider will land in Phase 8
            // and publish richer state (art mode on/off, art piece
            // title, input source, brightness, color tone).
            FrameTVDetailView(accessoryID: accessoryID)

        case .switch, .outlet, .lock, .fan, .blinds, .other:
            // Generic form-based detail still handles these well.
            AccessoryDetailView(accessoryID: accessoryID)
        }
    }
}
