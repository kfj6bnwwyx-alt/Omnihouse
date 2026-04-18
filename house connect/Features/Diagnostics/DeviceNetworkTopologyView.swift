//
//  DeviceNetworkTopologyView.swift
//  house connect
//
//  Pencil `eJwZy` — Device Network Topology. A diagnostics-flavored
//  radial graph of every accessory the app sees, arranged around a
//  central "home" hub. Linked devices (members of a multi-room audio
//  group, ongoing scene automation, etc.) are tinted primary and get
//  a line drawn back to the hub; standalone devices draw a muted gray
//  line and sit at smaller sizes on the ring.
//
//  The view has two segmented modes:
//    - Topology (default) — the radial graph
//    - List                — plain sectioned list (online / offline /
//                            active links) for anyone who wants a
//                            keyboard-friendly scan
//
//  We purposely do NOT try to show "real" network hops — this is not
//  a router admin tool. The "links" we render are cross-device
//  relationships we actually model (speaker groups today, automation
//  edges later). Anything else would make this screen a dishonest
//  mockup the moment you tapped a node.
//
//  Entry point:
//  ------------
//  Pushed from Settings → HOME → Network & Hubs. Uses a custom header
//  with back button (hidden nav bar pattern).
//

import SwiftUI

struct DeviceNetworkTopologyView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .topology

    enum Mode: Hashable { case topology, list }

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    modeSwitcher
                    if mode == .topology {
                        topologyCard
                    } else {
                        listCard
                    }
                    activeConnectionsSection
                    quickLinksRow
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Quick links

    private var quickLinksRow: some View {
        HStack(spacing: 12) {
            NavigationLink {
                NetworkListView(accessories: registry.allAccessories)
            } label: {
                quickLinkTile(icon: "list.bullet", title: "Device List")
            }
            .buttonStyle(.plain)

            NavigationLink {
                NetworkDiagnosticsView()
            } label: {
                quickLinkTile(icon: "waveform.path.ecg", title: "Diagnostics")
            }
            .buttonStyle(.plain)
        }
    }

    private func quickLinkTile(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.color.primary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.title)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(Theme.color.cardFill)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Header

    /// Custom header matching the Pencil comp — "Device Network" title
    /// with a gear icon on the right, plus back button.
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.chip,
                                         style: .continuous)
                            .fill(Theme.color.cardFill)
                            .shadow(color: .black.opacity(0.05),
                                    radius: 6, x: 0, y: 2)
                    )
            }
            .accessibilityLabel("Back")

            Text("Device Network")
                .font(Theme.font.screenTitle)
                .foregroundStyle(Theme.color.title)

            Spacer()

            NavigationLink {
                NetworkSettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.color.muted)
            }
            .accessibilityLabel("Network settings")
        }
    }

    // MARK: - Segment switcher

    /// Custom pill-style segment control matching the Pencil comp —
    /// rounded capsule background with accent fill on the active pill.
    private var modeSwitcher: some View {
        HStack(spacing: 3) {
            segmentButton("Topology", isActive: mode == .topology) {
                withAnimation(.easeInOut(duration: 0.2)) { mode = .topology }
            }
            segmentButton("List", isActive: mode == .list) {
                withAnimation(.easeInOut(duration: 0.2)) { mode = .list }
            }
        }
        .padding(3)
        .background(
            Capsule().fill(Theme.color.iconChipFill)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View mode")
    }

    private func segmentButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? .white : Theme.color.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    Capsule().fill(isActive ? Theme.color.primary : .clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityHint(isActive ? "" : "Switch to \(title) view")
    }

    // MARK: - Accessors

    private var interestingCategories: Set<Accessory.Category> {
        [.speaker, .lock, .camera, .thermostat, .sensor, .light]
    }

    private var nodes: [Accessory] {
        registry.allAccessories
            .filter { interestingCategories.contains($0.category) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var onlineCount: Int {
        nodes.reduce(0) { $0 + ($1.isReachable ? 1 : 0) }
    }

    /// A node counts as "linked" if it's a participant in a multi-room
    /// audio group with at least one other member. Future additions
    /// (automation routes, zone bridges) can OR into this predicate.
    private func isLinked(_ accessory: Accessory) -> Bool {
        if let group = accessory.speakerGroup,
           !group.otherMemberNames.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Topology

    private var topologyCard: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h: CGFloat = 340
            let center = CGPoint(x: w / 2, y: h / 2)
            let outerRadius = min(w, h) / 2 - 40
            let innerRadius = outerRadius * 0.54
            let positions = ringLayout(center: center, radius: outerRadius)

            ZStack {
                // Two concentric rings matching the Pencil comp.
                Circle()
                    .stroke(
                        Theme.color.primary.opacity(0.15),
                        style: StrokeStyle(lineWidth: 1.5)
                    )
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                    .position(center)
                    .accessibilityHidden(true)

                Circle()
                    .stroke(
                        Theme.color.primary.opacity(0.07),
                        style: StrokeStyle(lineWidth: 1)
                    )
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .position(center)
                    .accessibilityHidden(true)

                // Lines from hub to EVERY node — accent for linked,
                // gray for standalone.
                ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                    if let pt = positions[safe: idx] {
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: pt)
                        }
                        .stroke(
                            isLinked(node)
                                ? Theme.color.primary.opacity(0.55)
                                : Color.gray.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .accessibilityHidden(true)
                    }
                }

                // Central hub.
                ZStack {
                    Circle()
                        .fill(Theme.color.primary)
                        .frame(width: 64, height: 64)
                        .shadow(color: Theme.color.primary.opacity(0.35),
                                radius: 14, x: 0, y: 6)
                    Image(systemName: "house.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .position(center)
                .accessibilityLabel("Home hub")
                .accessibilityHint("Central hub connecting all devices")

                // Device nodes — linked nodes are larger.
                ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                    if let pt = positions[safe: idx] {
                        TopologyNode(
                            name: shortLabel(node),
                            icon: iconName(for: node.category),
                            isLinked: isLinked(node),
                            size: isLinked(node) ? nodeSize(for: idx, linked: true)
                                                 : nodeSize(for: idx, linked: false)
                        )
                        .position(pt)
                    }
                }

                // Status label — inside the card, top-left.
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.33, green: 0.77, blue: 0.49))
                        .frame(width: 8, height: 8)
                    Text("\(onlineCount) devices online")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.color.muted)
                }
                .position(x: 80, y: 18)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(onlineCount) devices online")

                // Legend — inside the card, bottom-left.
                HStack(spacing: 12) {
                    legendDot(color: Theme.color.primary, label: "Linked")
                    legendDot(color: Theme.color.iconChipFill, label: "Standalone")
                }
                .position(x: 78, y: h - 18)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Legend: Linked and Standalone")
            }
        }
        .frame(height: 340)
        .hcCard(padding: 12)
    }

    /// Linked nodes cycle through 56→48, standalone through 44→40,
    /// giving the Pencil comp's visual variety where closer/more
    /// important nodes feel weightier.
    private func nodeSize(for index: Int, linked: Bool) -> CGFloat {
        if linked {
            return index % 2 == 0 ? 56 : 48
        } else {
            return index % 2 == 0 ? 44 : 40
        }
    }

    /// Evenly distributes up to N nodes around a circle of the given
    /// radius. Deterministic so rerenders don't make nodes dance.
    private func ringLayout(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        let count = max(nodes.count, 1)
        var out: [CGPoint] = []
        for i in 0..<count {
            let angle = (2 * .pi) * (Double(i) / Double(count)) - (.pi / 2)
            out.append(CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            ))
        }
        return out
    }

    private func shortLabel(_ accessory: Accessory) -> String {
        let comps = accessory.name.split(separator: " ")
        if comps.count == 1 { return String(accessory.name.prefix(4)).uppercased() }
        let initials = comps.prefix(2).map { String($0.prefix(1)) }.joined()
        return initials.uppercased()
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

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.color.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    // MARK: - List mode

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if nodes.isEmpty {
                Text("No devices to show.")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            } else {
                ForEach(nodes) { node in
                    HStack(spacing: 12) {
                        IconChip(systemName: iconName(for: node.category), size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.name)
                                .font(Theme.font.cardTitle)
                                .foregroundStyle(Theme.color.title)
                            Text(isLinked(node) ? "Linked" : (node.isReachable ? "Online" : "Offline"))
                                .font(Theme.font.cardSubtitle)
                                .foregroundStyle(
                                    isLinked(node)
                                        ? Theme.color.primary
                                        : (node.isReachable
                                           ? Theme.color.subtitle
                                           : Color(red: 0.93, green: 0.29, blue: 0.27))
                                )
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(node.name), \(isLinked(node) ? "Linked" : (node.isReachable ? "Online" : "Offline"))")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }

    // MARK: - Active connections

    private var activeConnectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Connections")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)
                .accessibilityAddTraits(.isHeader)

            // Linked groups — accent icon, chevron, tappable.
            let groups = linkedGroups
            if !groups.isEmpty {
                ForEach(groups, id: \.id) { group in
                    linkedConnectionRow(group)
                }
            }

            // Standalone summary card — muted icon, no chevron.
            let standaloneDevices = nodes.filter { !isLinked($0) }
            if !standaloneDevices.isEmpty {
                standaloneCard(standaloneDevices)
            }

            if groups.isEmpty && standaloneDevices.isEmpty {
                Text("No active links right now.")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hcCard()
            }
        }
    }

    private func linkedConnectionRow(_ group: LinkedGroup) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.color.primary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.color.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text(group.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.muted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
        }
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Linked group: \(group.title), \(group.subtitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("View linked group details")
    }

    /// Standalone devices card — shows unlinked icon, lists device
    /// names joined by " · ", and "Standalone · Not linked" subtitle.
    /// No chevron (matches Pencil comp).
    private func standaloneCard(_ devices: [Accessory]) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.color.iconChipFill)
                    .frame(width: 40, height: 40)
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.color.muted)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(devices.map(\.name).joined(separator: " · "))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text("Standalone · Not linked")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.muted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Standalone devices: \(devices.map(\.name).joined(separator: ", ")), Not linked")
    }

    /// Materializes the unique linked-group tuples from the current
    /// nodes. Keyed by `speakerGroup.groupID` so a 4-speaker zone
    /// shows up as a single row, not four.
    private struct LinkedGroup: Hashable {
        let id: String
        let title: String
        let subtitle: String
    }

    private var linkedGroups: [LinkedGroup] {
        var seen = Set<String>()
        var out: [LinkedGroup] = []
        for node in nodes {
            guard let group = node.speakerGroup,
                  !group.otherMemberNames.isEmpty,
                  seen.insert(group.groupID).inserted
            else { continue }
            let title = ([node.name] + group.otherMemberNames).joined(separator: " ↔ ")
            let subtitle: String
            if let np = node.nowPlaying, let t = np.title {
                subtitle = "Sharing audio · \(t)"
            } else {
                subtitle = "Paired"
            }
            out.append(LinkedGroup(id: group.groupID, title: title, subtitle: subtitle))
        }
        return out
    }
}

// MARK: - Node view

private struct TopologyNode: View {
    let name: String
    let icon: String
    let isLinked: Bool
    var size: CGFloat = 48

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isLinked ? Theme.color.primary : Theme.color.iconChipFill)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(isLinked ? 0.15 : 0.05),
                            radius: isLinked ? 8 : 3, x: 0, y: 3)
                Image(systemName: icon)
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(isLinked ? .white : Theme.color.muted)
            }
            Text(name)
                .font(.system(size: max(7, size * 0.15), weight: .bold))
                .foregroundStyle(isLinked ? Theme.color.title : Theme.color.muted)
                .tracking(0.4)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(isLinked ? "Connected" : "Standalone")")
        .accessibilityHint(isLinked ? "Device is linked to a group" : "Device is not linked to any group")
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
