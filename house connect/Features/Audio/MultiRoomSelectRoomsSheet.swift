//
//  MultiRoomSelectRoomsSheet.swift
//  house connect
//
//  Pencil `g00bw` / `woiK9` / `375nI` — Select Rooms sheet for
//  multi-room audio. Shows all speakers with toggles; the user picks
//  which rooms join the group and taps the CTA to start playback.
//  Converted to T3/Swiss design system.
//

import SwiftUI

struct MultiRoomSelectRoomsSheet: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    /// The group coordinator when editing an existing group; nil when creating new.
    var coordinatorID: AccessoryID?

    @State private var selectedIDs: Set<AccessoryID> = []
    @State private var isCommitting = false
    @State private var commitError: String?

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            VStack(spacing: 0) {
                // Sheet header
                sheetHeader
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                TRule()

                // Now-playing mini bar (when editing an existing group)
                if let coordinator {
                    nowPlayingMiniBar(coordinator)
                }

                if speakers.isEmpty {
                    // Reuse the shared empty state component
                    NoSpeakersEmptyState(
                        onScanAgain: {
                            Task {
                                if let sonos = registry.provider(for: .sonos) {
                                    await sonos.refresh()
                                }
                            }
                        }
                    )
                } else {
                    // Room list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(speakers.enumerated()), id: \.element.id) { i, speaker in
                                if !speaker.isReachable {
                                    unavailableRow(speaker, isLast: i == speakers.count - 1)
                                } else {
                                    roomRow(speaker, isLast: i == speakers.count - 1)
                                }
                            }
                        }
                    }

                    Spacer()

                    TRule()
                    ctaButton
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 20)
                }
            }
        }
        .onAppear {
            if let cid = coordinatorID,
               let acc = registry.allAccessories.first(where: { $0.id == cid }),
               let group = acc.speakerGroup {
                selectedIDs.insert(cid)
                for speaker in speakers where speaker.speakerGroup?.groupID == group.groupID {
                    selectedIDs.insert(speaker.id)
                }
            }
        }
    }

    // MARK: - Data

    private var speakers: [Accessory] {
        registry.allAccessories
            .filter { $0.category == .speaker }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var coordinator: Accessory? {
        guard let cid = coordinatorID else { return nil }
        return registry.allAccessories.first { $0.id == cid }
    }

    private var selectedCount: Int { selectedIDs.count }

    // MARK: - Sheet header

    private var sheetHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                TLabel(text: "Multi-room audio")
                Text("Select rooms")
                    .font(T3.inter(24, weight: .medium))
                    .tracking(-0.6)
                    .foregroundStyle(T3.ink)
            }
            Spacer()
            Button { dismiss() } label: {
                T3IconImage(systemName: "xmark")
                    .frame(width: 12, height: 12)
                    .foregroundStyle(T3.sub)
                    .frame(width: 32, height: 32)
                    .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Now-playing mini bar

    private func nowPlayingMiniBar(_ coord: Accessory) -> some View {
        let np = coord.nowPlaying
        return HStack(spacing: 14) {
            // Album art placeholder — T3 ink square
            ZStack {
                Rectangle()
                    .fill(T3.ink)
                    .frame(width: 44, height: 44)
                T3IconImage(systemName: "music.note")
                    .frame(width: 16, height: 16)
                    .foregroundStyle(T3.sub)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(np?.title ?? "Not Playing")
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                TLabel(text: (np?.artist ?? coord.name).uppercased())
            }

            Spacer()

            T3IconImage(systemName: coord.playbackState == .playing ? "pause.fill" : "play.fill")
                .frame(width: 16, height: 16)
                .foregroundStyle(T3.ink)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(np?.title ?? "Not Playing") by \(np?.artist ?? coord.name)")
    }

    // MARK: - Room row

    private func roomRow(_ speaker: Accessory, isLast: Bool = false) -> some View {
        let isSelected = selectedIDs.contains(speaker.id)
        return HStack(spacing: 14) {
            T3IconImage(systemName: "hifispeaker.fill")
                .frame(width: 16, height: 16)
                .foregroundStyle(isSelected ? T3.accent : T3.sub)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(speaker.name)
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: speakerModelLabel(speaker).uppercased())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TPill(isOn: Binding(
                get: { isSelected },
                set: { on in
                    if on { selectedIDs.insert(speaker.id) }
                    else { selectedIDs.remove(speaker.id) }
                }
            ))
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(speaker.name), \(speakerModelLabel(speaker))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "remove from" : "add to") audio group")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Unavailable row (Pencil woiK9)

    private func unavailableRow(_ speaker: Accessory, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(T3.danger)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    T3IconImage(systemName: "hifispeaker.fill")
                        .frame(width: 14, height: 14)
                        .foregroundStyle(T3.danger)
                        .accessibilityHidden(true)
                    Text(speaker.name)
                        .font(T3.inter(14, weight: .medium))
                        .foregroundStyle(T3.ink)
                }
                Text("Speaker offline — last seen recently")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.danger)
                Text("Troubleshoot")
                    .font(T3.inter(12, weight: .medium))
                    .foregroundStyle(T3.accent)
                    .padding(.top, 2)
            }
            Spacer()
            TPill(isOn: .constant(false))
                .disabled(true)
                .opacity(0.4)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(speaker.name), speaker offline, last seen recently")
        .accessibilityHint("This speaker is unavailable and cannot be added to the group")
    }

    // MARK: - CTA button

    private var ctaButton: some View {
        VStack(spacing: 8) {
            if let error = commitError {
                Text(error)
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.danger)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await commitSelection() }
            } label: {
                HStack(spacing: 8) {
                    if isCommitting {
                        ProgressView()
                            .tint(T3.page)
                            .scaleEffect(0.8)
                            .accessibilityHidden(true)
                    } else {
                        T3IconImage(systemName: "play.fill")
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                    }
                    Text(isCommitting
                         ? "GROUPING…"
                         : "PLAY ON \(selectedCount) ROOM\(selectedCount == 1 ? "" : "S")")
                        .font(T3.mono(11))
                        .tracking(2)
                }
                .foregroundStyle(T3.page)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selectedCount > 0 && !isCommitting ? T3.ink : T3.sub)
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0 || isCommitting)
            .accessibilityLabel(isCommitting
                ? "Grouping speakers"
                : "Play on \(selectedCount) room\(selectedCount == 1 ? "" : "s")")
            .accessibilityHint(selectedCount > 0
                ? "Groups the selected rooms and starts playback"
                : "Select at least one room to start playback")
        }
    }

    // MARK: - Group commit

    private func commitSelection() async {
        isCommitting = true
        commitError = nil
        defer { isCommitting = false }

        let coordID: AccessoryID
        if let existing = coordinatorID {
            coordID = existing
        } else if let first = selectedIDs.first {
            coordID = first
        } else {
            return
        }

        let currentGroupID = registry.allAccessories
            .first(where: { $0.id == coordID })?.speakerGroup?.groupID
        let currentMembers: Set<AccessoryID> = Set(
            speakers.filter { speaker in
                guard let group = speaker.speakerGroup else { return false }
                return group.groupID == currentGroupID
            }.map(\.id)
        )

        let toJoin  = selectedIDs.subtracting(currentMembers).subtracting([coordID])
        let toLeave = currentMembers.subtracting(selectedIDs).subtracting([coordID])

        for speakerID in toJoin {
            do {
                try await registry.execute(.joinSpeakerGroup(target: coordID), on: speakerID)
            } catch {
                commitError = "Failed to add \(speakerName(speakerID)): \(error.localizedDescription)"
            }
        }
        for speakerID in toLeave {
            do {
                try await registry.execute(.leaveSpeakerGroup, on: speakerID)
            } catch {
                commitError = "Failed to remove \(speakerName(speakerID)): \(error.localizedDescription)"
            }
        }

        if commitError == nil { dismiss() }
    }

    private func speakerName(_ id: AccessoryID) -> String {
        speakers.first(where: { $0.id == id })?.name ?? "speaker"
    }

    private func speakerModelLabel(_ speaker: Accessory) -> String {
        if let room = registry.allRooms.first(where: { $0.id == speaker.id.nativeID }) {
            return room.name
        }
        return speaker.id.provider == .sonos ? "Sonos" : "Speaker"
    }
}
