//
//  NetworkListView.swift
//  house connect
//
//  Pencil `Z4SXt` — Enhanced "List" mode for the Device Network screen.
//  Searchable device list grouped by Connected / Offline with protocol
//  badges. Designed as a standalone view that takes `[Accessory]` input
//  so `DeviceNetworkTopologyView` can embed it in its List segment.
//

import SwiftUI

struct NetworkListView: View {
    let accessories: [Accessory]

    @State private var searchText = ""

    // MARK: - Computed

    private var filtered: [Accessory] {
        let sorted = accessories
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            roomName(for: $0).localizedCaseInsensitiveContains(searchText) ||
            protocolLabel(for: $0).localizedCaseInsensitiveContains(searchText)
        }
    }

    private var connected: [Accessory] { filtered.filter(\.isReachable) }
    private var offline: [Accessory] { filtered.filter { !$0.isReachable } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            searchBar

            if !connected.isEmpty {
                sectionHeader(
                    dotColor: Color(red: 0.33, green: 0.77, blue: 0.49),
                    title: "Connected",
                    count: connected.count
                )
                VStack(spacing: 0) {
                    ForEach(Array(connected.enumerated()), id: \.element.id) { idx, accessory in
                        if idx > 0 {
                            Divider()
                                .foregroundStyle(Theme.color.divider)
                                .padding(.leading, 52)
                        }
                        deviceRow(accessory)
                    }
                }
                .hcCard()
            }

            if !offline.isEmpty {
                sectionHeader(
                    dotColor: Theme.color.danger,
                    title: "Offline",
                    count: offline.count
                )
                VStack(spacing: 0) {
                    ForEach(Array(offline.enumerated()), id: \.element.id) { idx, accessory in
                        if idx > 0 {
                            Divider()
                                .foregroundStyle(Theme.color.divider)
                                .padding(.leading, 52)
                        }
                        deviceRow(accessory, muted: true)
                    }
                }
                .hcCard()
            }

            if connected.isEmpty && offline.isEmpty {
                Text("No devices match your search.")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.muted)
            TextField("Search devices...", text: $searchText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.title)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.color.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.muted)
                .accessibilityLabel("Filter")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                .fill(Theme.color.iconChipFill)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search devices")
    }

    // MARK: - Section header

    private func sectionHeader(dotColor: Color, title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)
            Text("(\(count))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.color.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count) devices")
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Device row

    private func deviceRow(_ accessory: Accessory, muted: Bool = false) -> some View {
        HStack(spacing: 12) {
            // Category icon in accent circle chip
            ZStack {
                Circle()
                    .fill(muted ? Theme.color.iconChipFill : Theme.color.primary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName(for: accessory.category))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(muted ? Theme.color.muted : Theme.color.primary)
            }

            // Name + room
            VStack(alignment: .leading, spacing: 2) {
                Text(accessory.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(muted ? Theme.color.muted : Theme.color.title)
                    .lineLimit(1)
                Text(roomName(for: accessory))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.color.muted)
                    .lineLimit(1)
            }

            Spacer()

            // Protocol badge
            protocolBadge(for: accessory, muted: muted)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessory.name), \(roomName(for: accessory)), \(protocolLabel(for: accessory)), \(muted ? "Offline" : "Connected")")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("View device details")
    }

    // MARK: - Protocol badge

    private func protocolBadge(for accessory: Accessory, muted: Bool) -> some View {
        let label = protocolLabel(for: accessory)
        let badgeColor = muted ? Theme.color.muted : protocolColor(for: accessory)
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(badgeColor.opacity(0.12))
            )
            .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func roomName(for accessory: Accessory) -> String {
        accessory.roomID ?? "Unassigned"
    }

    private func protocolLabel(for accessory: Accessory) -> String {
        switch accessory.id.provider {
        case .homeKit: "HomeKit"
        case .smartThings: "Wi-Fi"
        case .sonos: "Wi-Fi"
        case .nest: "Thread"
        case .homeAssistant: "Home Assistant"
        }
    }

    private func protocolColor(for accessory: Accessory) -> Color {
        switch accessory.id.provider {
        case .homeKit: Color(red: 0.42, green: 0.36, blue: 0.91) // purple
        case .smartThings: Color(red: 0.33, green: 0.77, blue: 0.49) // green
        case .sonos: Color(red: 0.33, green: 0.77, blue: 0.49) // green
        case .nest: Color(red: 0.55, green: 0.36, blue: 0.91) // purple
        case .homeAssistant: Color(red: 0.18, green: 0.73, blue: 0.83) // cyan
        }
    }

    private func iconName(for cat: Accessory.Category) -> String {
        switch cat {
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
}
