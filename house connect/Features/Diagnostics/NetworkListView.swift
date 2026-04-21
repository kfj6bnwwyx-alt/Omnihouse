//
//  NetworkListView.swift
//  house connect
//
//  Pencil `Z4SXt` — Device list for the Device Network screen.
//  Converted to T3/Swiss design system: TRule hairlines, T3 tokens,
//  no rounded cards, protocol badges as rectangular border tags.
//

import SwiftUI

struct NetworkListView: View {
    let accessories: [Accessory]

    @Environment(\.dismiss) private var dismiss
    @Environment(ProviderRegistry.self) private var registry
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
    private var offline:   [Accessory] { filtered.filter { !$0.isReachable } }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Device Network", onBack: { dismiss() })

                    TTitle(
                        title: "Device list.",
                        subtitle: "\(accessories.count) DEVICE\(accessories.count == 1 ? "" : "S")"
                    )

                    // Search row
                    searchRow

                    // Connected
                    if !connected.isEmpty {
                        TSectionHead(title: "Connected", count: "\(connected.count)")
                        ForEach(Array(connected.enumerated()), id: \.element.id) { i, acc in
                            deviceRow(acc, isLast: i == connected.count - 1)
                        }
                    }

                    // Offline
                    if !offline.isEmpty {
                        TSectionHead(title: "Offline", count: "\(offline.count)")
                        ForEach(Array(offline.enumerated()), id: \.element.id) { i, acc in
                            deviceRow(acc, muted: true, isLast: i == offline.count - 1)
                        }
                    }

                    // Empty state
                    if connected.isEmpty && offline.isEmpty {
                        Text("No devices match your search.")
                            .font(T3.inter(13, weight: .regular))
                            .foregroundStyle(T3.sub)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 32)
                            .accessibilityAddTraits(.isStaticText)
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Search row

    private var searchRow: some View {
        HStack(spacing: 10) {
            T3IconImage(systemName: "magnifyingglass")
                .frame(width: 14, height: 14)
                .foregroundStyle(T3.sub)
                .accessibilityHidden(true)

            TextField("Search devices…", text: $searchText)
                .font(T3.inter(13, weight: .regular))
                .foregroundStyle(T3.ink)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    T3IconImage(systemName: "xmark.circle.fill")
                        .frame(width: 14, height: 14)
                        .foregroundStyle(T3.sub)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search devices")
    }

    // MARK: - Device row

    private func deviceRow(
        _ accessory: Accessory,
        muted: Bool = false,
        isLast: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: iconName(for: accessory.category))
                .frame(width: 16, height: 16)
                .foregroundStyle(muted ? T3.sub : T3.ink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(accessory.name)
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(muted ? T3.sub : T3.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                TLabel(text: roomName(for: accessory).uppercased())
            }

            Spacer()

            // Protocol badge — flat rectangular border tag
            Text(protocolLabel(for: accessory))
                .font(T3.mono(10))
                .tracking(1.2)
                .foregroundStyle(muted ? T3.sub : T3.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(Rectangle().stroke(muted ? T3.rule : T3.sub, lineWidth: 1))
                .accessibilityHidden(true)

            T3IconImage(systemName: "chevron.right")
                .frame(width: 10, height: 10)
                .foregroundStyle(T3.sub)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(accessory.name), \(roomName(for: accessory)), \(protocolLabel(for: accessory)), \(muted ? "Offline" : "Connected")"
        )
        .accessibilityHint("View device details")
    }

    // MARK: - Helpers

    private func roomName(for accessory: Accessory) -> String {
        guard let roomID = accessory.roomID else { return "Unassigned" }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? "Unassigned"
    }

    private func protocolLabel(for accessory: Accessory) -> String {
        switch accessory.id.provider {
        case .homeKit:       "HomeKit"
        case .smartThings:   "Wi-Fi"
        case .sonos:         "Wi-Fi"
        case .nest:          "Thread"
        case .homeAssistant: "HA"
        }
    }

    private func iconName(for cat: Accessory.Category) -> String {
        switch cat {
        case .light:      "lightbulb.fill"
        case .switch:     "switch.2"
        case .outlet:     "poweroutlet.type.b.fill"
        case .thermostat: "thermometer.medium"
        case .lock:       "lock.fill"
        case .sensor:     "sensor.fill"
        case .camera:     "video.fill"
        case .fan:        "fan.fill"
        case .blinds:     "blinds.horizontal.closed"
        case .speaker:    "hifispeaker.fill"
        case .television: "tv.fill"
        case .appleTV:    "tv.fill"
        case .smokeAlarm: "smoke.fill"
        case .other:      "questionmark.app.fill"
        }
    }
}
