//
//  T3DeviceDetailView.swift
//  house connect
//
//  T3 device detail router — dispatches to the right T3 detail
//  screen based on device category. Falls back to old views for
//  categories that don't have a T3 version yet.
//

import SwiftUI

struct T3DeviceDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    var body: some View {
        Group {
            if let accessory {
                if !accessory.isReachable {
                    T3DeviceOfflineView(accessoryID: accessoryID)
                } else {
                    routedView(for: accessory)
                }
            } else {
                // Device not found — show T3-styled unavailable
                ZStack {
                    T3.page.ignoresSafeArea()
                    VStack(spacing: 12) {
                        TLabel(text: "Device unavailable")
                        Text("This device is no longer reported by its provider.")
                            .font(T3.inter(13, weight: .regular))
                            .foregroundStyle(T3.sub)
                            .multilineTextAlignment(.center)
                    }
                    .padding(T3.screenPadding)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private func routedView(for accessory: Accessory) -> some View {
        switch accessory.category {
        case .light:
            T3LightDetailView(accessoryID: accessoryID)

        case .thermostat:
            T3ThermostatView(accessoryID: accessoryID)

        case .lock:
            T3LockDetailView(accessoryID: accessoryID)

        case .speaker:
            if accessory.id.provider == .sonos,
               let parts = accessory.groupedParts, parts.count > 1 {
                T3SonosBondedGroupDetailView(accessoryID: accessoryID)
            } else {
                T3SpeakerDetailView(accessoryID: accessoryID)
            }

        case .television:
            T3FrameTVDetailView(accessoryID: accessoryID)

        case .appleTV:
            T3AppleTVDetailView(accessoryID: accessoryID)

        case .camera:
            T3CameraDetailView(accessoryID: accessoryID)

        case .smokeAlarm, .sensor, .switch, .outlet, .fan, .blinds, .other:
            T3AccessoryDetailView(accessoryID: accessoryID)
        }
    }
}
