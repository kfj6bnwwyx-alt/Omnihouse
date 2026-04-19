//
//  T3DeviceNetworkTopologyView.swift
//  house connect
//
//  T3/Swiss network topology — flat, hairline-divided list of every
//  accessory the app sees, sectioned by provider (which is the closest
//  model we have to "network" today: Zigbee lives under HomeAssistant,
//  Matter under HomeKit, etc.). Each row shows a leading icon, name +
//  mono caption with id/provider detail, and a trailing status dot.
//
//  Graph redraw intentionally deferred — see TODO(design) below.
//
//  Entry point: Settings → Network & Hubs (SettingsDestination.networkTopology).
//

import SwiftUI

struct T3DeviceNetworkTopologyView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    // TODO(design): topology graph redraw pending Pencil comp — the
    // legacy radial-graph layout was stripped; only the list-style
    // T3 treatment ships here for now.

    private var interestingCategories: Set<Accessory.Category> {
        [.speaker, .lock, .camera, .thermostat, .sensor, .light, .smokeAlarm, .switch, .outlet, .fan, .blinds, .television, .appleTV, .other]
    }

    private var nodes: [Accessory] {
        registry.allAccessories
            .filter { interestingCategories.contains($0.category) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var onlineCount: Int {
        nodes.reduce(0) { $0 + ($1.isReachable ? 1 : 0) }
    }

    /// Groups nodes by provider — providers stand in for "network"
    /// until we model real network fabrics (Zigbee / Z-Wave / Thread).
    private var sections: [(provider: ProviderID, nodes: [Accessory])] {
        let grouped = Dictionary(grouping: nodes, by: { $0.id.provider })
        return grouped
            .map { (provider: $0.key, nodes: $0.value) }
            .sorted { $0.provider.displayLabel.localizedCaseInsensitiveCompare($1.provider.displayLabel) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(
                        backLabel: "Settings",
                        rightLabel: "\(onlineCount)/\(nodes.count) ONLINE",
                        onBack: { dismiss() }
                    )

                    TTitle(
                        title: "Topology",
                        subtitle: "\(nodes.count) device\(nodes.count == 1 ? "" : "s") across \(sections.count) network\(sections.count == 1 ? "" : "s")"
                    )

                    TSectionHead(title: "NETWORK TOPOLOGY", count: "\(nodes.count) DEVICES")

                    TRule()

                    // Section per provider (network)
                    ForEach(Array(sections.enumerated()), id: \.offset) { pair in
                        sectionView(pair.element.provider, pair.element.nodes)
                    }

                    TRule()

                    // Push rows to child diagnostics views
                    quickLinkRow(title: "Device list", destination: AnyView(NetworkListView(accessories: registry.allAccessories)))
                    TRule()
                    quickLinkRow(title: "Diagnostics", destination: AnyView(NetworkDiagnosticsView()))
                    TRule()
                    quickLinkRow(title: "Network settings", destination: AnyView(NetworkSettingsView()))
                    TRule()

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Per-network section

    @ViewBuilder
    private func sectionView(_ provider: ProviderID, _ items: [Accessory]) -> some View {
        HStack {
            Text(provider.displayLabel.uppercased())
                .font(T3.mono(10))
                .tracking(1.6)
                .foregroundStyle(T3.sub)
            Spacer()
            TLabel(text: "\(items.count)")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 18)
        .padding(.bottom, 8)

        ForEach(Array(items.enumerated()), id: \.element.id) { pair in
            nodeRow(pair.element, isLast: pair.offset == items.count - 1)
        }
    }

    private func nodeRow(_ accessory: Accessory, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: iconName(for: accessory.category))
                .frame(width: 18, height: 18)
                .foregroundStyle(accessory.isReachable ? T3.ink : T3.sub)

            VStack(alignment: .leading, spacing: 2) {
                Text(accessory.name)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                Text(nodeCaption(accessory))
                    .font(T3.mono(10))
                    .tracking(1.0)
                    .foregroundStyle(T3.sub)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }

            Spacer()

            Circle()
                .fill(accessory.isReachable ? T3.ok : T3.danger)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) {
            if isLast { TRule() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessory.name), \(accessory.isReachable ? "online" : "offline")")
    }

    private func nodeCaption(_ accessory: Accessory) -> String {
        let category = categoryLabel(accessory.category)
        let id = accessory.id.nativeID
        // Trim long native IDs so the mono caption stays single-line.
        let trimmed = id.count > 14 ? String(id.prefix(14)) + "…" : id
        return "\(category) · \(trimmed)"
    }

    private func categoryLabel(_ c: Accessory.Category) -> String {
        switch c {
        case .light: "Light"
        case .switch: "Switch"
        case .outlet: "Outlet"
        case .thermostat: "Thermostat"
        case .lock: "Lock"
        case .sensor: "Sensor"
        case .camera: "Camera"
        case .fan: "Fan"
        case .blinds: "Blinds"
        case .speaker: "Speaker"
        case .television: "TV"
        case .appleTV: "Apple TV"
        case .smokeAlarm: "Smoke"
        case .other: "Device"
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
        case .camera: "video"
        case .fan: "fan"
        case .blinds: "blinds.horizontal.closed"
        case .speaker: "hifispeaker.fill"
        case .television: "tv.fill"
        case .appleTV: "tv.fill"
        case .smokeAlarm: "smoke.fill"
        case .other: "questionmark.app.fill"
        }
    }

    // MARK: - Quick link row

    private func quickLinkRow(title: String, destination: AnyView) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack {
                Text(title)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                Spacer()
                T3IconImage(systemName: "chevron.right")
                    .frame(width: 12, height: 12)
                    .foregroundStyle(T3.sub)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 16)
        }
        .buttonStyle(.t3Row)
        .accessibilityLabel(title)
    }
}
