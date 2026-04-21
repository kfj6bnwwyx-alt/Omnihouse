//
//  T3SpeakerDetailView.swift
//  house connect
//
//  T3/Swiss speaker detail — now-playing card, transport row with
//  72px orange play/pause, volume tick scale, group-with toggles.
//

import SwiftUI

struct T3SpeakerDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var isPlaying: Bool = true
    @State private var volume: Double = 0.65
    @State private var toast: Toast?
    // Captured at the start of a volume drag so we can revert the
    // tick scale if the committed value fails to apply.
    @State private var dragStartVolume: Double = 0
    @State private var dragInProgress: Bool = false

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String {
        guard let accessory, let roomID = accessory.roomID else { return "Room" }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? "Room"
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(
                        backLabel: roomName,
                        rightLabel: accessory?.id.provider.displayLabel.uppercased(),
                        onBack: { dismiss() }
                    )

                    // Eyebrow + state
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            if isPlaying { TDot(size: 8) }
                            TLabel(text: isPlaying ? "Playing" : "Idle")
                        }

                        Text(accessory?.name ?? "Speaker")
                            .font(T3.inter(42, weight: .medium))
                            .tracking(-1.4)
                            .foregroundStyle(T3.ink)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.7)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                    TRule()

                    // Now-playing card
                    nowPlayingCard

                    // Transport row
                    transportRow
                        .padding(.vertical, 24)

                    TRule()

                    // Volume
                    TSectionHead(title: "Volume")

                    HStack(spacing: 14) {
                        volumeScale
                        Text("\(Int(volume * 100))")
                            .font(T3.inter(22, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.bottom, 20)

                    TRule()

                    // Group with
                    groupSection

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast, duration: 4)
        .onAppear {
            if let acc = accessory {
                isPlaying = acc.playbackState == .playing
                volume = Double(acc.volumePercent ?? 65) / 100.0
            }
        }
    }

    // MARK: - Now Playing Card

    private var nowPlayingCard: some View {
        HStack(spacing: 16) {
            // Album art placeholder — ink square with orange dot
            ZStack {
                Rectangle()
                    .fill(T3.ink)
                    .frame(width: 64, height: 64)
                TDot(size: 10)
            }

            VStack(alignment: .leading, spacing: 4) {
                TLabel(text: "Now Playing")
                Text(accessory?.nowPlaying?.title ?? "Treats")
                    .font(T3.inter(16, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(accessory?.nowPlaying?.artist ?? "Sleigh Bells")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
        }
        .padding(18)
        .background(
            Rectangle()
                .fill(T3.panel)
                .overlay(
                    Rectangle().stroke(T3.rule, lineWidth: 1)
                )
        )
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 18)
    }

    // MARK: - Transport Row

    private var transportRow: some View {
        HStack(spacing: 20) {
            Spacer()

            // Previous — outlined circle
            Button {
                Task { @MainActor in
                    await T3ActionFeedback.perform(
                        action: { try await registry.execute(.previous, on: accessoryID) },
                        toast: { toast = .error("Couldn't skip back") },
                        errorDescription: "Speaker previous"
                    )
                }
            } label: {
                Circle()
                    .stroke(T3.rule, lineWidth: 1)
                    .fill(T3.panel)
                    .frame(width: 52, height: 52)
                    .overlay(
                        T3IconImage(systemName: "backward.fill")
                            .frame(width: 16, height: 16)
                            .foregroundStyle(T3.ink)
                    )
            }
            .buttonStyle(.plain)

            // Play/Pause — 72px orange primary button
            Button {
                let previous = isPlaying
                isPlaying.toggle()
                let nowPlaying = isPlaying
                Task { @MainActor in
                    await T3ActionFeedback.perform(
                        action: { try await registry.execute(nowPlaying ? .play : .pause, on: accessoryID) },
                        onFailure: { isPlaying = previous },
                        toast: { toast = .error("Couldn't \(nowPlaying ? "play" : "pause")") },
                        errorDescription: "Speaker transport"
                    )
                }
            } label: {
                Circle()
                    .fill(T3.accent)
                    .frame(width: 72, height: 72)
                    .overlay(
                        T3IconImage(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 24, height: 24)
                            .foregroundStyle(T3.page)
                    )
            }
            .buttonStyle(.plain)

            // Next — outlined circle
            Button {
                Task { @MainActor in
                    await T3ActionFeedback.perform(
                        action: { try await registry.execute(.next, on: accessoryID) },
                        toast: { toast = .error("Couldn't skip forward") },
                        errorDescription: "Speaker next"
                    )
                }
            } label: {
                Circle()
                    .stroke(T3.rule, lineWidth: 1)
                    .fill(T3.panel)
                    .frame(width: 52, height: 52)
                    .overlay(
                        T3IconImage(systemName: "forward.fill")
                            .frame(width: 16, height: 16)
                            .foregroundStyle(T3.ink)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Volume Scale

    private var volumeScale: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(0..<41, id: \.self) { i in
                        let f = Double(i) / 40.0
                        let major = i % 5 == 0
                        let on = f <= volume
                        Rectangle()
                            .fill(on ? T3.ink : T3.rule)
                            .frame(width: 1, height: major ? 14 : 7)
                            .position(x: f * geo.size.width, y: major ? 7 : 3.5)
                    }

                    TDot(size: 10)
                        .position(x: volume * geo.size.width, y: 22)
                }
                .frame(width: geo.size.width, height: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !dragInProgress {
                                dragStartVolume = volume
                                dragInProgress = true
                            }
                            volume = max(0, min(1, value.location.x / geo.size.width))
                        }
                        .onEnded { _ in
                            let startValue = dragStartVolume
                            let committedValue = volume
                            dragInProgress = false
                            Task { @MainActor in
                                await T3ActionFeedback.perform(
                                    action: { try await registry.execute(.setVolume(Int(committedValue * 100)), on: accessoryID) },
                                    onFailure: { volume = startValue },
                                    successHaptic: .none,
                                    toast: { toast = .error("Couldn't set volume") },
                                    errorDescription: "Speaker volume drag"
                                )
                            }
                        }
                )
            }
            .frame(height: 28)
        }
    }

    // MARK: - Group Section

    /// Other speaker accessories from the same provider — candidates
    /// for multi-room grouping. Excludes self, sorted by name.
    private var peerSpeakers: [Accessory] {
        registry.allAccessories
            .filter { $0.id.provider == accessoryID.provider
                   && $0.id != accessoryID
                   && $0.category == .speaker }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// True iff `peer` is currently in the same casual group as `accessory`.
    /// Uses `speakerGroup.groupID` for exact membership; falls back to
    /// checking `otherMemberNames` so the UI works even when HA hasn't
    /// propagated a groupID yet.
    private func isGrouped(with peer: Accessory) -> Bool {
        guard let myGroup = accessory?.speakerGroup else { return false }
        if let peerGroupID = peer.speakerGroup?.groupID {
            return myGroup.groupID == peerGroupID
        }
        // Fallback: check by name
        let peerRoomName = roomNameFor(peer)
        return myGroup.otherMemberNames.contains(peerRoomName)
    }

    private func roomNameFor(_ acc: Accessory) -> String {
        guard let roomID = acc.roomID else { return acc.name }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == acc.id.provider }?
            .name ?? acc.name
    }

    @ViewBuilder
    private var groupSection: some View {
        let peers = peerSpeakers
        if !peers.isEmpty {
            VStack(spacing: 0) {
                TSectionHead(
                    title: "Group with",
                    count: "\(peers.count) SPEAKER\(peers.count == 1 ? "" : "S")"
                )

                ForEach(Array(peers.enumerated()), id: \.element.id) { i, peer in
                    let grouped = isGrouped(with: peer)

                    Button {
                        Task { @MainActor in
                            if grouped {
                                // Tell the peer to leave the group
                                await T3ActionFeedback.perform(
                                    action: { try await registry.execute(.leaveSpeakerGroup, on: peer.id) },
                                    toast: { toast = .error("Couldn't ungroup \(peer.name)") },
                                    errorDescription: "Speaker ungroup"
                                )
                            } else {
                                // Tell the peer to join the current accessory's group
                                await T3ActionFeedback.perform(
                                    action: { try await registry.execute(.joinSpeakerGroup(target: accessoryID), on: peer.id) },
                                    toast: { toast = .error("Couldn't group with \(peer.name)") },
                                    errorDescription: "Speaker group join"
                                )
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(peer.name)
                                    .font(T3.inter(15, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                TLabel(text: roomNameFor(peer).uppercased())
                            }
                            Spacer()
                            TPill(isOn: .constant(grouped))
                                .allowsHitTesting(false)
                        }
                    }
                    .buttonStyle(.t3Row)
                    .accessibilityLabel("\(peer.name), \(grouped ? "grouped" : "not grouped")")
                    .accessibilityHint(grouped ? "Tap to ungroup" : "Tap to add to group")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }
}
