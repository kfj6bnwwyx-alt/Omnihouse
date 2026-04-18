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
    @Environment(ProviderRegistry.self) private var registry
    #if os(iOS)
    @Environment(SmokeAlertController.self) private var smokeAlertController
    #endif

    @State private var selectedTab: T3Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            NavigationStack {
                Group {
                    switch selectedTab {
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
                    }
                }
                .navigationDestination(for: SettingsDestination.self) { dest in
                    switch dest {
                    case .providers: T3ProvidersView()
                    case .rooms: T3RoomsTabView()
                    case .scenes: T3ScenesListView()
                    case .automations: T3AutomationsView()
                    case .audioZones: AudioZonesMapView()
                    case .networkTopology: DeviceNetworkTopologyView()
                    case .about: AboutView()
                    case .helpFAQ: HelpFAQView()
                    case .notifications: NotificationPreferencesView()
                    case .appearance: AppearanceView()
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)

            // Floating T3 tab bar
            T3TabBar(selection: $selectedTab)
        }
        #if os(iOS)
        .fullScreenCover(
            isPresented: Binding(
                get: { smokeAlertController.activeAlertContext != nil },
                set: { if !$0 { Task { await smokeAlertController.end(reason: .simulationStopped) } } }
            )
        ) {
            if let ctx = smokeAlertController.activeAlertContext {
                SmokeAlarmAlertView(
                    roomName: ctx.roomName ?? "Unknown Room",
                    deviceName: ctx.deviceName ?? "Smoke Alarm",
                    detectedAt: ctx.triggeredAt,
                    onSilence: { Task { await smokeAlertController.end(reason: .simulationStopped) } },
                    onDismiss: { Task { await smokeAlertController.end(reason: .simulationStopped) } }
                )
            }
        }
        #endif
    }
}
