//
//  T3RootView.swift
//  house connect
//
//  T3/Swiss root view — replaces the system TabView with a custom
//  floating T3TabBar and switches between T3 tab screens.
//  Drop this into RootContainerView to activate the T3 design.
//

import SwiftUI

struct T3RootView: View {
    @State private var navigator = T3TabNavigator()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            NavigationStack(path: $navigator.path) {
                Group {
                    switch navigator.selection {
                    case .home:
                        T3HomeDashboardView()
                    case .rooms:
                        T3RoomsTabView()
                    case .devices:
                        T3DevicesTabView()
                    case .settings:
                        T3SettingsTabView()
                    }
                }
                .navigationDestination(for: AccessoryID.self) { id in
                    T3DeviceDetailView(accessoryID: id)
                }
                .navigationDestination(for: Room.self) { room in
                    T3RoomDetailView(roomID: room.id, providerID: room.provider)
                }
                .navigationDestination(for: T3HomeDashboardView.HomeDestination.self) { dest in
                    switch dest {
                    case .notifications: T3NotificationsView()
                    case .energy: T3EnergyView()
                    case .activity: T3ActivityView()
                    }
                }
                .navigationDestination(for: ProviderID.self) { providerID in
                    T3ProviderDetailView(providerID: providerID)
                }
                .navigationDestination(for: SettingsDestination.self) { dest in
                    switch dest {
                    case .profile: T3ProfileView()
                    case .providers: T3ProvidersView()
                    case .rooms: T3RoomsSettingsView()
                    case .scenes: T3ScenesListView()
                    case .automations: T3AutomationsView()
                    case .audioZones: T3AudioZonesMapView()
                    case .networkTopology: T3DeviceNetworkTopologyView()
                    case .about: T3AboutView()
                    case .helpFAQ: T3HelpFAQView()
                    case .notifications: T3NotificationPreferencesView()
                    case .appearance: T3AppearanceView()
                    case .manageDeviceLinks: T3ManageDeviceLinksView()
                    case .energySettings: T3EnergySettingsView()
                    case .haDiagnostics: T3HADiagnosticsView()
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)

            // Floating T3 tab bar
            T3TabBar(selection: $navigator.selection)
        }
        // Global HA disconnection banner — shows on every tab whenever
        // Home Assistant's WebSocket is down. Sits below the status bar
        // and above the tab content. See Core/UI/HAConnectionBanner.swift.
        .overlay(alignment: .top) {
            HAConnectionBanner()
        }
        // Inject navigator AFTER the overlay so both the primary ZStack
        // content AND the banner see it. With the env injected inside
        // the overlay, HAConnectionBanner crashes looking for it.
        .environment(navigator)
        // Note: provider startup is now owned by `RootContainerView`,
        // which gates the splash transition on startAll completion.
        // Do not call `registry.startAll()` here — it would re-start
        // providers after the splash already awaited them.
    }
}
