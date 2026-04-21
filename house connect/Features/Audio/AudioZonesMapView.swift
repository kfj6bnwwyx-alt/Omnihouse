//
//  AudioZonesMapView.swift
//  house connect
//
//  Pencil `ixmFl` — Audio Zones Map. Top-down view of every speaker,
//  with active multi-room groups shown as connected nodes. Two modes:
//  Map (spatial) and List. Converted to T3/Swiss design system.
//

import SwiftUI

struct AudioZonesMapView: View {
    @Environment(ProviderRegistry.self) private var registry

    @State private var mode: Mode = .map
    @State private var showSelectRooms = false
    @State private var editCoordinatorID: AccessoryID?

    enum Mode: Hashable { case map, list }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Page header row — title + create button
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            TLabel(text: "Audio")
                            Text("Zones.")
                                .font(T3.inter(42, weight: .medium))
                                .tracking(-1.4)
                                .foregroundStyle(T3.ink)
                        }
                        Spacer()
                        Button {
                            showSelectRooms = true
                        } label: {
                            T3IconImage(systemName: "plus")
                                .frame(width: 14, height: 14)
                                .foregroundStyle(T3.ink)
                                .frame(width: 36, height: 36)
                                .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Create audio zone")
                        .accessibilityHint("Opens room selection to create a new multi-room group")
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                    TRule()

                    // Mode switcher
                    Picker("Mode", selection: $mode) {
                        Text("Map View").tag(Mode.map)
                        Text("List View").tag(Mode.list)
                    }
                    .pickerStyle(.segmented)
                    .tint(T3.accent)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 14)
                    .accessibilityLabel("View mode")
                    .accessibilityHint("Switch between map and list view")

                    TRule()

                    if mode == .map {
                        mapSection
                    } else {
                        listSection
                    }

                    linkedSection

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSelectRooms) {
            MultiRoomSelectRoomsSheet(coordinatorID: editCoordinatorID)
                .environment(registry)
        }
        .onChange(of: showSelectRooms) { _, isPresented in
            if !isPresented {
                editCoordinatorID = nil
                Task {
                    if let sonos = registry.provider(for: .sonos) as? SonosProvider {
                        await sonos.refreshTopologyAndRebuild()
                    }
                }
            }
        }
    }

    // MARK: - Speakers

    private var speakers: [Accessory] {
        registry.allAccessories
            .filter { $0.category == .speaker }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var groupsByID: [String: [Accessory]] {
        Dictionary(grouping: speakers.filter { $0.speakerGroup != nil }) {
            $0.speakerGroup?.groupID ?? ""
        }
        .filter { $0.value.count > 1 }
    }

    // MARK: - Map section

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Speaker map", count: "\(speakers.count)")
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                let positions = layout(in: CGSize(width: w, height: h))

                ZStack {
                    if speakers.isEmpty {
                        VStack(spacing: 10) {
                            T3IconImage(systemName: "hifispeaker.slash")
                                .frame(width: 28, height: 28)
                                .foregroundStyle(T3.sub)
                            Text("No speakers found")
                                .font(T3.inter(13, weight: .regular))
                                .foregroundStyle(T3.sub)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Group link lines
                    ForEach(Array(groupsByID.keys), id: \.self) { gid in
                        let members = groupsByID[gid] ?? []
                        let points = members.compactMap { acc in
                            speakers.firstIndex(where: { $0.id == acc.id })
                                .flatMap { idx in positions[safe: idx] }
                        }
                        if points.count > 1 {
                            Path { path in
                                path.move(to: points[0])
                                for pt in points.dropFirst() { path.addLine(to: pt) }
                            }
                            .stroke(
                                T3.accent.opacity(0.55),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .accessibilityHidden(true)
                        }
                    }

                    // Speaker nodes
                    ForEach(Array(speakers.enumerated()), id: \.element.id) { idx, speaker in
                        if let pos = positions[safe: idx] {
                            SpeakerNode(
                                name: speaker.name,
                                isGrouped: speaker.speakerGroup != nil &&
                                    (groupsByID[speaker.speakerGroup?.groupID ?? ""]?.count ?? 0) > 1
                            )
                            .position(pos)
                            .accessibilityLabel(
                                "\(speaker.name), \((groupsByID[speaker.speakerGroup?.groupID ?? ""]?.count ?? 0) > 1 ? "grouped" : "standalone") speaker"
                            )
                            .accessibilityAddTraits(.isStaticText)
                        }
                    }
                }
            }
            .frame(height: 320)
            .padding(.horizontal, T3.screenPadding)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { TRule() }
        }
    }

    private func layout(in size: CGSize) -> [CGPoint] {
        let cols = 3, rows = 3
        let padding: CGFloat = 36
        let usableW = size.width - padding * 2
        let usableH = size.height - padding * 2
        let stepX = usableW / CGFloat(cols - 1)
        let stepY = usableH / CGFloat(rows - 1)
        return (0..<max(speakers.count, 1)).map { i in
            CGPoint(
                x: padding + CGFloat(i % cols) * stepX,
                y: padding + CGFloat((i / cols) % rows) * stepY
            )
        }
    }

    // MARK: - List section

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "All speakers", count: "\(speakers.count)")
            if speakers.isEmpty {
                Text("No speakers on the network yet.")
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 16)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { TRule() }
                    .accessibilityAddTraits(.isStaticText)
            } else {
                ForEach(Array(speakers.enumerated()), id: \.element.id) { i, speaker in
                    HStack(spacing: 14) {
                        T3IconImage(systemName: "hifispeaker.fill")
                            .frame(width: 16, height: 16)
                            .foregroundStyle(T3.ink)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(speaker.name)
                                .font(T3.inter(14, weight: .medium))
                                .foregroundStyle(T3.ink)
                                .lineLimit(1)
                            TLabel(text: speakerStatus(speaker).uppercased())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { if i == speakers.count - 1 { TRule() } }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(speaker.name), \(speakerStatus(speaker))")
                }
            }
        }
    }

    private func speakerStatus(_ accessory: Accessory) -> String {
        if let group = accessory.speakerGroup, !group.otherMemberNames.isEmpty {
            return "Linked · " + group.otherMemberNames.joined(separator: ", ")
        }
        return "Standalone"
    }

    // MARK: - Currently linked section

    private var linkedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(
                title: "Currently linked",
                count: groupsByID.isEmpty ? nil : "\(groupsByID.count)"
            )

            if groupsByID.isEmpty {
                Text("No active zones. Link speakers from any Now Playing card.")
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 16)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { TRule() }
                    .accessibilityAddTraits(.isStaticText)
            } else {
                ForEach(Array(groupsByID.keys.enumerated()), id: \.element) { i, gid in
                    if let members = groupsByID[gid] {
                        linkedRow(members: members, isLast: i == groupsByID.count - 1)
                    }
                }
            }
        }
    }

    private func linkedRow(members: [Accessory], isLast: Bool) -> some View {
        let names = members.map(\.name).joined(separator: " + ")
        let coord = members.first { $0.speakerGroup?.isCoordinator == true } ?? members[0]
        let nowPlaying = coord.nowPlaying?.title ?? "Paused"

        return NavigationLink {
            MultiRoomNowPlayingView(coordinatorID: coord.id)
        } label: {
            HStack(spacing: 14) {
                // Zone icon
                Rectangle()
                    .fill(T3.ink)
                    .frame(width: 28, height: 28)
                    .overlay(
                        T3IconImage(systemName: "music.note")
                            .frame(width: 12, height: 12)
                            .foregroundStyle(T3.page)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(names)
                        .font(T3.inter(14, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .lineLimit(1)
                    TLabel(text: nowPlaying.uppercased())
                }

                Spacer()

                // Edit Zone tag button (stops propagation via separate action)
                Button {
                    editCoordinatorID = coord.id
                    showSelectRooms = true
                } label: {
                    Text("EDIT ZONE")
                        .font(T3.mono(9))
                        .tracking(1.2)
                        .foregroundStyle(T3.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(Rectangle().stroke(T3.sub, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit zone for \(names)")
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { if isLast { TRule() } }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(names), now playing \(nowPlaying)")
        .accessibilityHint("Double tap to open now playing controls")
    }
}

// MARK: - Speaker node (map)

/// T3-styled speaker bubble on the map. Accent-filled when grouped,
/// rule-bordered outline when standalone.
private struct SpeakerNode: View {
    let name: String
    let isGrouped: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Rectangle()
                    .fill(isGrouped ? T3.ink : T3.page)
                    .frame(width: 48, height: 48)
                    .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                T3IconImage(systemName: "hifispeaker.fill")
                    .frame(width: 16, height: 16)
                    .foregroundStyle(isGrouped ? T3.page : T3.sub)
                if isGrouped {
                    TDot(size: 6)
                        .offset(x: 14, y: -14)
                }
            }
            Text(name)
                .font(T3.mono(9))
                .tracking(0.8)
                .foregroundStyle(T3.ink)
                .lineLimit(1)
                .frame(width: 64)
        }
    }
}

// MARK: - Array safe index

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
