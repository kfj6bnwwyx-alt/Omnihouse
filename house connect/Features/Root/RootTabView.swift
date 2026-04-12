//
//  RootTabView.swift
//  house connect
//
//  Top-level navigation container. The Pencil design pins a 4-tab bar to
//  the bottom of every screen. The current tabs are:
//     HOME       · room-grouped dashboard (grid of rooms is the primary
//                  real estate — the user already has this view on Home,
//                  so a duplicate "All Rooms" tab was redundant)
//     DEVICES    · flat list of every accessory across every provider,
//                  independent of room assignment. Primary answer to
//                  "show me everything on my network" — especially
//                  useful for Sonos (no rooms in Phase 3a) and for
//                  unassigned SmartThings / HomeKit devices.
//     ADD        · first-class Add Device flow (not a modal sheet)
//     SETTINGS   · connections, rooms CRUD, scenes, etc.
//
//  Each tab owns its own NavigationStack so pushing inside DEVICES
//  doesn't collapse when the user pops out to HOME and back.
//
//  History: the second tab used to be "ROOMS" (AllRoomsView), but that
//  duplicated the room grid already shown on the Home dashboard. The
//  AllRoomsView screen still exists — it's now reached from
//  Settings → Rooms & Zones instead of being a top-level tab. Changed
//  2026-04-11.
//
//  We intentionally do NOT wire the ADD tab into a modal sheet — it's a
//  first-class destination in the design and gets its own `AddDeviceView`
//  that pushes through NavigationStack like any other tab.
//

import SwiftUI

struct RootTabView: View {
    @Environment(ProviderRegistry.self) private var registry
    #if os(iOS)
    @Environment(SmokeAlertController.self) private var smokeAlertController
    #endif

    enum Tab: Hashable {
        case home, devices, add, settings
    }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeDashboardView()
                    .navigationDestination(for: AccessoryID.self) { id in
                        DeviceDetailView(accessoryID: id)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)

            NavigationStack {
                AllDevicesView()
                    .navigationDestination(for: AccessoryID.self) { id in
                        DeviceDetailView(accessoryID: id)
                    }
                    .navigationDestination(for: SettingsDestination.self) { dest in
                        switch dest {
                        case .providers: ProvidersSettingsView()
                        case .rooms: AllRoomsView()
                        case .scenes: ScenesListView()
                        case .audioZones: AudioZonesMapView()
                        case .networkTopology: DeviceNetworkTopologyView()
                        case .about: AboutView()
                        case .helpFAQ: HelpFAQView()
                        case .notifications: NotificationPreferencesView()
                        case .appearance: AppearanceView()
                        }
                    }
            }
            .tabItem {
                Label("Devices", systemImage: "rectangle.stack.fill")
            }
            .tag(Tab.devices)

            NavigationStack {
                AddDeviceView()
            }
            .tabItem {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .tag(Tab.add)

            NavigationStack {
                SettingsView()
                    .navigationDestination(for: AccessoryID.self) { id in
                        DeviceDetailView(accessoryID: id)
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        .tint(Theme.color.primary)
        .task {
            await registry.startAll()
        }
        #if os(iOS)
        // Full-screen emergency modal (Pencil `RAISW`). Bound to the
        // controller's `activeAlertContext` so it presents the instant
        // smoke is reported — independent of the Live Activity path,
        // which may be disabled in Settings.
        .fullScreenCover(
            item: Binding(
                get: { smokeAlertController.activeAlertContext },
                set: { smokeAlertController.activeAlertContext = $0 }
            )
        ) { context in
            SmokeEmergencyModal(
                context: context,
                onSilence: {
                    Task { await smokeAlertController.acknowledge() }
                }
            )
        }
        #endif
    }
}
