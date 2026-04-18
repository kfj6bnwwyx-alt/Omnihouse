//
//  T3AudioZonesMapView.swift
//  house connect
//
//  T3/Swiss port of the Audio Zones screen. Replaces the legacy map
//  `AudioZonesMapView`. Instead of a spatial floor-plan (which requires
//  coordinates we don't have), we lean into the T3 aesthetic: a flat
//  hairline-divided vertical list of zones where each row surfaces the
//  member speakers as mono chips plus inline transport + volume.
//
//  Tap a zone row → pushes T3MultiRoomNowPlayingView for fine-grained
//  routing + per-speaker control.
//

import SwiftUI

struct T3AudioZonesMapView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var showSelectRooms = false
    @State private var editCoordinatorID: AccessoryID?

    private var speakers: [Accessory] {
        registry.allAccessories
            .filter { $0.category == .speaker }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Grouped multi-room zones keyed by provider groupID. Singletons
    /// are filtered out — a "group of one" is just a standalone speaker.
    private var groupsByID: [String: [Accessory]] {
        Dictionary(grouping: speakers.filter { $0.speakerGroup != nil }) {
            $0.speakerGroup?.groupID ?? ""
        }
        .filter { $0.value.count > 1 }
    }

    /// Standalone speakers (not part of any multi-room group) rendered
    /// below the active zones as single-speaker rows.
    private var standaloneSpeakers: [Accessory] {
        speakers.filter { acc in
            guard let group = acc.speakerGroup else { return true }
            return (groupsByID[group.groupID]?.count ?? 0) <= 1
        }
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Settings", onBack: { dismiss() })
                    TTitle(
                        title: "Audio Zones.",
                        subtitle: nil,
                        isActive: !groupsByID.isEmpty
                    )

                    TSectionHead(
                        title: "Zones",
                        count: String(format: "%02d · %02d SPKRS", groupsByID.count, speakers.count)
                    )

                    if speakers.isEmpty {
                        emptyState
                    } else {
                        // Active multi-room groups
                        ForEach(Array(groupsByID.keys.sorted()), id: \.self) { gid in
                            if let members = groupsByID[gid] {
                                zoneRow(members: members)
                            }
                        }

                        // Standalone speakers
                        if !standaloneSpeakers.isEmpty {
                            TSectionHead(title: "Standalone", count: String(format: "%02d", standaloneSpeakers.count))
                            ForEach(standaloneSpeakers) { speaker in
                                standaloneRow(speaker)
                            }
                        }
                    }

                    // Create zone CTA
                    Button {
                        editCoordinatorID = nil
                        showSelectRooms = true
                    } label: {
                        HStack {
                            T3IconImage(systemName: "plus")
                                .frame(width: 14, height: 14)
                                .foregroundStyle(T3.sub)
                            Text("Create zone")
                                .font(T3.inter(14, weight: .medium))
                                .foregroundStyle(T3.sub)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(
                            Rectangle()
                                .stroke(T3.rule, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 16)

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSelectRooms) {
            // Reuse the legacy select-rooms sheet until a T3 port lands.
            // Its surfaces sit inside a presented sheet so the T3 vs legacy
            // styling mismatch is visually contained.
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            TLabel(text: "NO SPEAKERS")
            Text("No compatible speakers on the network yet.")
                .font(T3.inter(14, weight: .regular))
                .foregroundStyle(T3.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 22)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Zone row

    private func zoneRow(members: [Accessory]) -> some View {
        let coord = members.first { $0.speakerGroup?.isCoordinator == true } ?? members[0]
        let isPlaying = coord.playbackState == .playing
        let title = coord.nowPlaying?.title ?? (isPlaying ? "Now Playing" : "Idle")
        let artist = coord.nowPlaying?.artist ?? "—"
        let chipString = members
            .map { $0.name.uppercased() }
            .joined(separator: " · ")

        return NavigationLink {
            T3MultiRoomNowPlayingView(coordinatorID: coord.id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if isPlaying { TDot(size: 8) }
                    TLabel(text: isPlaying ? "PLAYING" : "IDLE")
                    Spacer()
                    TLabel(text: "\(members.count) RMS")
                }

                Text(zoneName(members: members))
                    .font(T3.inter(20, weight: .bold))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(chipString)
                        .font(T3.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(T3.sub)
                }

                HStack(spacing: 2) {
                    Text(title)
                        .font(T3.inter(13, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .lineLimit(1)
                    Text(" · ")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                    Text(artist)
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineLimit(1)
                    Spacer()
                    T3IconImage(systemName: "chevron.right")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(T3.sub)
                }
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
        }
        .buttonStyle(.t3Row)
    }

    private func zoneName(members: [Accessory]) -> String {
        let coord = members.first { $0.speakerGroup?.isCoordinator == true } ?? members[0]
        if let roomID = coord.roomID,
           let room = registry.allRooms.first(where: { $0.id == roomID && $0.provider == coord.id.provider }) {
            return room.name
        }
        return members.first?.name ?? "Zone"
    }

    // MARK: - Standalone row

    private func standaloneRow(_ speaker: Accessory) -> some View {
        NavigationLink(value: speaker.id) {
            HStack(spacing: 12) {
                T3IconImage(systemName: "music.note")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(T3.ink)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(speaker.name)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    TLabel(text: speaker.playbackState == .playing ? "PLAYING" : "IDLE")
                }
                Spacer()
                T3IconImage(systemName: "chevron.right")
                    .frame(width: 12, height: 12)
                    .foregroundStyle(T3.sub)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
        }
        .buttonStyle(.t3Row)
    }
}
