//
//  ProviderDevicesListView.swift
//  house connect
//
//  A per-provider device list reachable from Settings → Connections.
//  The Connections screen used to just show a dumb count ("Devices: 12")
//  for each provider, which meant the only way to open an individual
//  accessory from Settings was to bounce back to the Home or Rooms tab
//  and hunt for it. That felt like a dead end on a page whose entire
//  reason for existing is "manage this connection". Now the count row
//  is a NavigationLink that pushes this view, which simply filters
//  `registry.allAccessories` by `providerID` and lists every accessory
//  the provider has surfaced — tappable, drilling into the same
//  `DeviceDetailView` the Home/Rooms tabs use via the Settings tab's
//  existing `.navigationDestination(for: AccessoryID.self)` registration.
//
//  Visual styling matches the rest of the Pencil redesign (hcCard rows
//  with IconChip + name + subtitle), so the drill-down feels native to
//  the redesigned Settings stack rather than a form revival.
//
//  NOTE ON NAVIGATION (2026-04-11): rows use a VIEW-based NavigationLink
//  that names `DeviceDetailView` directly rather than a value-based
//  `NavigationLink(value: accessory.id)`. The value-based variant
//  requires `.navigationDestination(for: AccessoryID.self)` to be
//  registered and visible from this point in the stack; in practice,
//  pushing THIS view out of a Form inside `ProvidersSettingsView` put
//  us far enough down that SwiftUI wouldn't resolve the root-level
//  destination, and taps fell through silently (so the list just sat
//  there re-rendered, looking like it "repeated"). A view-based link
//  sidesteps the whole lookup and keeps this screen's behavior
//  self-contained, which is fine because this is the only place that
//  pushes device detail out of Settings.
//

import SwiftUI

struct ProviderDevicesListView: View {
    @Environment(ProviderRegistry.self) private var registry

    let providerID: ProviderID

    private var provider: (any AccessoryProvider)? {
        registry.provider(for: providerID)
    }

    private var accessories: [Accessory] {
        registry.allAccessories
            .filter { $0.id.provider == providerID }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// Map a roomID back to a human name so each row can show "Living Room"
    /// as a subtitle. Rooms come from the same provider, so we narrow the
    /// lookup to avoid colliding IDs across providers.
    private func roomName(for accessory: Accessory) -> String? {
        guard let roomID = accessory.roomID else { return nil }
        return provider?.rooms.first(where: { $0.id == roomID })?.name
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if accessories.isEmpty {
                    emptyState
                } else {
                    ForEach(accessories) { accessory in
                        NavigationLink {
                            T3DeviceDetailView(accessoryID: accessory.id)
                                .environment(registry)
                        } label: {
                            DeviceListRow(
                                accessory: accessory,
                                roomName: roomName(for: accessory)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationTitle(providerID.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No devices yet")
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)
            Text("Once \(providerID.displayLabel) publishes accessories, they'll appear here. Try tapping Refresh on the Connections screen.")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }
}

// MARK: - Row

private struct DeviceListRow: View {
    let accessory: Accessory
    let roomName: String?

    var body: some View {
        HStack(spacing: 14) {
            IconChip(systemName: iconName, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(accessory.name)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)

                Text(subtitle)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }

    /// `Category → SF Symbol`. Mirrors the mapping used in RoomDetailView's
    /// DeviceRowCard so a single accessory looks the same in every list.
    private var iconName: String {
        switch accessory.category {
        case .light: "lightbulb.fill"
        case .switch: "switch.2"
        case .outlet: "poweroutlet.type.b.fill"
        case .thermostat: "thermometer.medium"
        case .lock: "lock.fill"
        case .sensor: "sensor.fill"
        case .camera: "video.fill"
        case .fan: "fan.fill"
        case .blinds: "blinds.horizontal.closed"
        case .speaker: "hifispeaker.fill"
        case .television: "tv.fill"
        case .smokeAlarm: "smoke.fill"
        case .other: "questionmark.app.fill"
        }
    }

    /// Secondary line — prefers room name if assigned, otherwise falls
    /// back to the category label so the row is never blank.
    private var subtitle: String {
        if let roomName, !roomName.isEmpty {
            return roomName
        }
        if !accessory.isReachable {
            return "Offline"
        }
        return accessory.category.rawValue.capitalized
    }
}
