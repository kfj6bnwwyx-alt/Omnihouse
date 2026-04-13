//
//  AudioZonesMapView.swift
//  house connect
//
//  Pencil `ixmFl` — Audio Zones Map. A top-down floor-plan-ish view of
//  every speaker in the home, where speakers currently in the same
//  multi-room group are tinted primary and visually connected with a
//  line. Below the map sits a "Currently Linked" list of active groups
//  with an Edit Zone shortcut.
//
//  The view has two segmented modes:
//    - Map View (default) — the spatial layout
//    - List View           — a boring sectioned list of groups, useful
//                            on tiny screens or for VoiceOver
//
//  Data source:
//  ------------
//  We iterate `registry.allAccessories` and pick out speakers — the
//  same merging the Devices tab already does (a Sonos player is the
//  only thing we have "zones" on today, but the filter is category
//  based so a future AirPlay provider slots in cleanly).
//
//  Layout math:
//  ------------
//  We don't have actual coordinates for rooms. Instead we arrange up
//  to eight speakers on a soft grid (3 columns × 3 rows) centered in
//  the map frame. Position is stable per-speaker across re-renders
//  because it's derived from the speaker's index in a sorted array,
//  not a random seed. Grouped speakers are connected with a single
//  Path that walks the grouped positions in order — the whole point
//  is to show "these things are acting as one", not to be a network
//  graph.
//

import SwiftUI

struct AudioZonesMapView: View {
    @Environment(ProviderRegistry.self) private var registry

    @State private var mode: Mode = .map
    @State private var showSelectRooms = false
    @State private var editCoordinatorID: AccessoryID?

    enum Mode: Hashable { case map, list }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                modeSwitcher
                if mode == .map {
                    mapCard
                } else {
                    listCard
                }
                linkedSection
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
            .padding(.top, 8)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationTitle("Audio Zones")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSelectRooms) {
            MultiRoomSelectRoomsSheet(coordinatorID: editCoordinatorID)
                .environment(registry)
        }
        .onChange(of: showSelectRooms) { _, isPresented in
            if !isPresented {
                editCoordinatorID = nil
                // Refresh topology after the user committed group changes
                // so the zone map picks up the new grouping.
                Task {
                    if let sonos = registry.provider(for: .sonos) as? SonosProvider {
                        await sonos.refreshTopologyAndRebuild()
                    }
                }
            }
        }
    }

    // MARK: - Header / toggle

    private var header: some View {
        HStack {
            Text("Audio Zones")
                .font(Theme.font.screenTitle)
                .foregroundStyle(Theme.color.title)
            Spacer()
            Button {
                showSelectRooms = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create audio zone")
            .accessibilityHint("Opens room selection to create a new multi-room group")
        }
    }

    private var modeSwitcher: some View {
        Picker("Mode", selection: $mode) {
            Text("Map View").tag(Mode.map)
            Text("List View").tag(Mode.list)
        }
        .pickerStyle(.segmented)
        .tint(Theme.color.primary)
        .accessibilityLabel("View mode")
        .accessibilityHint("Switch between map and list view of audio zones")
    }

    // MARK: - Speakers

    /// The set of things we render. Sorted by name so positions stay
    /// stable even if the registry reorders its internal array.
    private var speakers: [Accessory] {
        registry.allAccessories
            .filter { $0.category == .speaker }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Speakers the user has placed into the same multi-room group are
    /// keyed by the provider's opaque groupID. A group of one is really
    /// "standalone"; we filter those out of the overlay logic.
    private var groupsByID: [String: [Accessory]] {
        Dictionary(grouping: speakers.filter { $0.speakerGroup != nil }) {
            $0.speakerGroup?.groupID ?? ""
        }
        .filter { $0.value.count > 1 }
    }

    // MARK: - Map card

    /// Renders the floor-plan-ish map. Positions are derived from a
    /// 3x3 soft grid over a fixed aspect ratio so the whole composition
    /// scales with the screen width but never changes shape.
    private var mapCard: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let positions = layout(in: CGSize(width: w, height: h))

            ZStack {
                // Empty state when no speakers are discovered.
                if speakers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "hifispeaker.slash")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.color.muted)
                        Text("No speakers found")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.color.subtitle)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                // Group link lines. Drawn UNDER the nodes so they look
                // like they originate behind each circle.
                ForEach(Array(groupsByID.keys), id: \.self) { gid in
                    let members = groupsByID[gid] ?? []
                    let points = members.compactMap { acc in
                        speakers.firstIndex(where: { $0.id == acc.id })
                            .flatMap { idx in positions[safe: idx] }
                    }
                    if points.count > 1 {
                        Path { path in
                            path.move(to: points[0])
                            for pt in points.dropFirst() {
                                path.addLine(to: pt)
                            }
                        }
                        .stroke(
                            Theme.color.primary.opacity(0.55),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .accessibilityHidden(true)
                    }
                }

                // Speaker nodes.
                ForEach(Array(speakers.enumerated()), id: \.element.id) { idx, speaker in
                    if let pos = positions[safe: idx] {
                        SpeakerNode(
                            name: speaker.name,
                            isGrouped: speaker.speakerGroup != nil &&
                                (groupsByID[speaker.speakerGroup?.groupID ?? ""]?.count ?? 0) > 1
                        )
                        .position(pos)
                        .accessibilityLabel("\(speaker.name), \(speaker.speakerGroup != nil && (groupsByID[speaker.speakerGroup?.groupID ?? ""]?.count ?? 0) > 1 ? "grouped" : "standalone") speaker")
                        .accessibilityAddTraits(.isStaticText)
                    }
                }
            }
        }
        .frame(height: 320)
        .hcCard(padding: 12)
    }

    /// Computes node centers on a 3x3 grid inset a bit from the card
    /// edges. Extra speakers beyond 9 fall back to a second row loop
    /// — rare enough not to matter visually.
    private func layout(in size: CGSize) -> [CGPoint] {
        let cols = 3
        let rows = 3
        let padding: CGFloat = 36
        let usableW = size.width - padding * 2
        let usableH = size.height - padding * 2
        let stepX = usableW / CGFloat(cols - 1)
        let stepY = usableH / CGFloat(rows - 1)
        var out: [CGPoint] = []
        for i in 0..<max(speakers.count, 1) {
            let col = i % cols
            let row = (i / cols) % rows
            out.append(CGPoint(
                x: padding + CGFloat(col) * stepX,
                y: padding + CGFloat(row) * stepY
            ))
        }
        return out
    }

    // MARK: - List mode

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if speakers.isEmpty {
                Text("No speakers on the network yet.")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .accessibilityAddTraits(.isStaticText)
            } else {
                ForEach(speakers) { speaker in
                    HStack(spacing: 12) {
                        IconChip(systemName: "hifispeaker.fill", size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(speaker.name)
                                .font(Theme.font.cardTitle)
                                .foregroundStyle(Theme.color.title)
                            Text(speakerStatus(speaker))
                                .font(Theme.font.cardSubtitle)
                                .foregroundStyle(Theme.color.subtitle)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(speaker.name), \(speakerStatus(speaker))")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }

    private func speakerStatus(_ accessory: Accessory) -> String {
        if let group = accessory.speakerGroup, !group.otherMemberNames.isEmpty {
            return "Linked with " + group.otherMemberNames.joined(separator: ", ")
        }
        return "Standalone"
    }

    // MARK: - Currently linked

    /// A single row per active group. Mirrors the Pencil composition
    /// underneath the map: album-tile icon, "Room A + Room B", a soft
    /// "Edit Zone" button on the trailing edge.
    private var linkedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Currently Linked")
                .font(Theme.font.sectionHeader)
                .foregroundStyle(Theme.color.title)

            if groupsByID.isEmpty {
                Text("No active zones. Link speakers from any Now Playing card.")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hcCard()
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel("No active zones. Link speakers from any Now Playing card.")
            } else {
                ForEach(Array(groupsByID.keys), id: \.self) { gid in
                    if let members = groupsByID[gid] {
                        linkedRow(members: members)
                    }
                }
            }
        }
    }

    private func linkedRow(members: [Accessory]) -> some View {
        let names = members.map(\.name).joined(separator: " + ")
        let coord = members.first { $0.speakerGroup?.isCoordinator == true } ?? members[0]
        let nowPlaying = coord.nowPlaying?.title ?? "Paused"
        return HStack(spacing: 12) {
            IconChip(systemName: "music.note", size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(names)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text(nowPlaying)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .lineLimit(1)
            }
            Spacer()
            Button("Edit Zone") {
                editCoordinatorID = coord.id
                showSelectRooms = true
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.color.primary))
            .accessibilityLabel("Edit zone for \(names)")
            .accessibilityHint("Opens room selection to modify this audio zone")
        }
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(names), now playing \(nowPlaying)")
    }
}

// MARK: - Speaker node

/// One circular speaker bubble on the map. Filled primary when the
/// speaker is part of an active multi-room group; otherwise a muted
/// chip fill so non-grouped speakers fade visually into the map.
private struct SpeakerNode: View {
    let name: String
    let isGrouped: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isGrouped ? Theme.color.primary : Theme.color.iconChipFill)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(isGrouped ? 0.15 : 0.06),
                            radius: isGrouped ? 10 : 4,
                            x: 0, y: 4)
                Image(systemName: "hifispeaker.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isGrouped ? .white : Theme.color.subtitle)
            }
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.color.title)
                .lineLimit(1)
        }
    }
}

// MARK: - Array safe index

/// Local safe-index helper so the layout math doesn't trap when the
/// speaker count mismatches the position buffer.
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
