//
//  MultiRoomSelectRoomsSheet.swift
//  house connect
//
//  Pencil `g00bw` / `woiK9` / `375nI` — Select Rooms sheet for
//  multi-room audio. Shown when the user taps "+" on Audio Zones or
//  "Edit Zone" on a linked group. Presents all speakers with toggles;
//  the user picks which rooms join the group and taps the CTA to start
//  playback.
//
//  Three visual states:
//    - Normal (`g00bw`): room list with toggles, now-playing mini bar
//    - Speaker unavailable (`woiK9`): one room shows an offline card
//      with "Troubleshoot" link and a disabled toggle
//    - No speakers (`375nI`): empty state with scan button and
//      troubleshooting tips
//
//  Data source:
//  ------------
//  Speakers come from `registry.allAccessories` filtered to `.speaker`.
//  The coordinator (if editing an existing group) is passed in; its
//  now-playing metadata fills the mini bar. Toggle state is local —
//  the CTA commits the selection.
//

import SwiftUI

struct MultiRoomSelectRoomsSheet: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    /// The group coordinator, if editing an existing group. Nil when
    /// creating a new group from the Audio Zones "+" button.
    var coordinatorID: AccessoryID?

    @State private var selectedIDs: Set<AccessoryID> = []
    @State private var isCommitting = false
    @State private var commitError: String?

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if let coordinator = coordinator {
                    nowPlayingMiniBar(coordinator)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                if speakers.isEmpty {
                    noSpeakersState
                } else {
                    roomList
                        .padding(.top, 8)

                    Spacer()

                    ctaButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            // Pre-select speakers that are already in the group.
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

    private var selectedCount: Int {
        selectedIDs.count
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Select Rooms")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.color.title)
                Text("Choose where to play music")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.color.muted)
            }
            Spacer()
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Theme.color.iconChipFill)
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.color.subtitle)
                }
            }
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Mini now-playing bar

    private func nowPlayingMiniBar(_ coord: Accessory) -> some View {
        let np = coord.nowPlaying
        return HStack(spacing: 12) {
            // Album art placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.13, blue: 0.17))
                    .frame(width: 48, height: 48)
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.color.muted)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(np?.title ?? "Not Playing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(np?.artist ?? coord.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "pause.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.12, green: 0.13, blue: 0.17))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(np?.title ?? "Not Playing") by \(np?.artist ?? coord.name)")
    }

    // MARK: - Room list

    private var roomList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(speakers) { speaker in
                    if !speaker.isReachable {
                        unavailableRow(speaker)
                    } else {
                        roomRow(speaker)
                    }

                    if speaker.id != speakers.last?.id {
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    private func roomRow(_ speaker: Accessory) -> some View {
        let isSelected = selectedIDs.contains(speaker.id)
        return HStack(spacing: 12) {
            Image(systemName: "hifispeaker.fill")
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? Theme.color.primary : Theme.color.muted)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(speaker.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Text(speakerModelLabel(speaker))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { on in
                    if on { selectedIDs.insert(speaker.id) }
                    else { selectedIDs.remove(speaker.id) }
                }
            ))
            .labelsHidden()
            .tint(Theme.color.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(speaker.name), \(speakerModelLabel(speaker))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "remove from" : "add to") audio group")
        .accessibilityAddTraits(.isButton)
    }

    /// Unavailable speaker row — matches Pencil `woiK9`. Red-tinted
    /// background, "Speaker offline" subtitle, Troubleshoot link,
    /// disabled toggle.
    private func unavailableRow(_ speaker: Accessory) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.color.danger.opacity(0.1))
                        .frame(width: 42, height: 42)
                    Image(systemName: "hifispeaker.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.color.danger)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(speaker.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.color.title)
                    Text("Speaker offline — last seen recently")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.color.danger)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("", isOn: .constant(false))
                    .labelsHidden()
                    .disabled(true)
            }

            HStack {
                Spacer()
                Text("Troubleshoot")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color.primary)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.color.danger.opacity(0.04))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(speaker.name), speaker offline, last seen recently")
        .accessibilityHint("This speaker is unavailable and cannot be added to the group")
    }

    // MARK: - No speakers empty state

    /// Full empty state — matches Pencil `375nI`. Large speaker icon,
    /// "No Speakers Found", description, scan button, troubleshooting
    /// card, and manual setup link.
    private var noSpeakersState: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                // Icon
                ZStack {
                    Circle()
                        .fill(Theme.color.iconChipFill)
                        .frame(width: 96, height: 96)
                    Image(systemName: "hifispeaker.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Theme.color.muted)
                }
                .accessibilityHidden(true)

                // Title + description
                Text("No Speakers Found")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.color.title)

                Text("We couldn't find any compatible speakers on your network. Make sure your speakers are powered on and connected to WiFi.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.color.subtitle)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 12)

                // Scan button
                Button {
                    Task {
                        if let sonos = registry.provider(for: .sonos) {
                            await sonos.refresh()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Scan Again")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 48)
                    .background(Capsule().fill(Theme.color.primary))
                }
                .accessibilityLabel("Scan again for speakers")
                .accessibilityHint("Searches the network for compatible speakers")

                // Troubleshooting card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Troubleshooting")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.color.title)

                    troubleshootTip("Check speaker power and WiFi")
                    troubleshootTip("Ensure app and speakers are on same network")
                    troubleshootTip("Restart your router if issues persist")
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.color.cardFill)
                )
                .padding(.horizontal, 12)

                // Manual link
                Text("Set up a speaker manually")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.color.primary)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens manual speaker setup")

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
    }

    private func troubleshootTip(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.color.primary.opacity(0.12))
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.subtitle)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        VStack(spacing: 8) {
            if let error = commitError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await commitSelection() }
            } label: {
                HStack(spacing: 8) {
                    if isCommitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(isCommitting ? "Grouping…" : "Play on \(selectedCount) Room\(selectedCount == 1 ? "" : "s")")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.color.primary)
                )
            }
            .disabled(selectedCount == 0 || isCommitting)
            .opacity(selectedCount > 0 && !isCommitting ? 1 : 0.5)
            .accessibilityLabel(isCommitting ? "Grouping speakers" : "Play on \(selectedCount) room\(selectedCount == 1 ? "" : "s")")
            .accessibilityHint(selectedCount > 0 ? "Groups the selected rooms and starts playback" : "Select at least one room to start playback")
        }
    }

    // MARK: - Group commit

    /// Dispatches join/leave commands to form the desired group.
    /// Joins are processed first (so the coordinator exists before
    /// followers try to attach), then leaves. Serialized to avoid
    /// topology race conditions on the Sonos side.
    private func commitSelection() async {
        isCommitting = true
        commitError = nil
        defer { isCommitting = false }

        // Determine the coordinator — existing group's coordinator,
        // or the first selected speaker if creating a new group.
        let coordID: AccessoryID
        if let existing = coordinatorID {
            coordID = existing
        } else if let first = selectedIDs.first {
            coordID = first
        } else {
            return
        }

        // Determine which speakers need to join vs leave.
        let currentGroupID = registry.allAccessories
            .first(where: { $0.id == coordID })?.speakerGroup?.groupID

        let currentMembers: Set<AccessoryID> = Set(
            speakers.filter { speaker in
                guard let group = speaker.speakerGroup else { return false }
                return group.groupID == currentGroupID
            }.map(\.id)
        )

        let toJoin = selectedIDs.subtracting(currentMembers).subtracting([coordID])
        let toLeave = currentMembers.subtracting(selectedIDs).subtracting([coordID])

        // Process joins first (serialize to avoid topology races)
        for speakerID in toJoin {
            do {
                try await registry.execute(.joinSpeakerGroup(target: coordID), on: speakerID)
            } catch {
                commitError = "Failed to add \(speakerName(speakerID)): \(error.localizedDescription)"
            }
        }

        // Then leaves
        for speakerID in toLeave {
            do {
                try await registry.execute(.leaveSpeakerGroup, on: speakerID)
            } catch {
                commitError = "Failed to remove \(speakerName(speakerID)): \(error.localizedDescription)"
            }
        }

        if commitError == nil {
            dismiss()
        }
    }

    private func speakerName(_ id: AccessoryID) -> String {
        speakers.first(where: { $0.id == id })?.name ?? "speaker"
    }

    // MARK: - Helpers

    /// Best-effort model label. If the speaker comes from Sonos, we
    /// know the model via the discovery record; otherwise fall back
    /// to the provider display name.
    private func speakerModelLabel(_ speaker: Accessory) -> String {
        // The speaker's room name gives a decent secondary label when
        // we don't have a hardware model string.
        if let room = registry.allRooms.first(where: { $0.id == speaker.id.nativeID }) {
            return room.name
        }
        return speaker.id.provider == .sonos ? "Sonos" : "Speaker"
    }
}
