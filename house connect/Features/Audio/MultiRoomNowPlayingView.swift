//
//  MultiRoomNowPlayingView.swift
//  house connect
//
//  Pencil `v5vpc` / `co524` / `pyUlJ` — Expanded Now Playing screen
//  for multi-room audio groups. Shows album art, track metadata,
//  transport controls, a progress bar, and per-room volume cards.
//  Handles room-added toasts (co524) and connection-lost states (pyUlJ).
//

import SwiftUI

struct MultiRoomNowPlayingView: View {
    let coordinatorID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var toast: Toast?

    // MARK: - Derived state

    private var coordinator: Accessory? {
        registry.allAccessories.first { $0.id == coordinatorID }
    }

    private var nowPlaying: NowPlaying? {
        coordinator?.nowPlaying
    }

    private var playbackState: PlaybackState? {
        coordinator?.playbackState
    }

    private var isPlaying: Bool {
        playbackState == .playing
    }

    /// Display names of other rooms in the group.
    private var otherRoomNames: [String] {
        coordinator?.speakerGroup?.otherMemberNames ?? []
    }

    /// The coordinator's own room name (looked up from the registry).
    private var coordinatorRoomName: String {
        guard let coordinator, let roomID = coordinator.roomID else {
            return coordinator?.name ?? "Speaker"
        }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == coordinator.id.provider }?
            .name ?? coordinator.name
    }

    /// All room names in the group (coordinator + others).
    private var allRoomNames: [String] {
        [coordinatorRoomName] + otherRoomNames
    }

    private var totalRoomCount: Int {
        allRoomNames.count
    }

    /// Accessory objects for the other group members (looked up by name).
    private var memberAccessories: [Accessory] {
        let others = otherRoomNames
        return registry.allAccessories.filter { acc in
            acc.category == .speaker && acc.id != coordinatorID &&
            (others.contains(acc.name) || others.contains {
                guard let roomID = acc.roomID else { return false }
                return registry.allRooms
                    .first { $0.id == roomID && $0.provider == acc.id.provider }?
                    .name == $0
            })
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                customHeader
                albumArt
                songInfo
                progressBar
                transportControls
                roomVolumeSection
                Spacer(minLength: 32)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
            .padding(.top, 8)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }

    // MARK: - Custom header

    private var customHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.color.title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Text("Now Playing")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            Spacer()

            Button {
                // Cast action placeholder
            } label: {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.color.title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("AirPlay")
            .accessibilityHint("Choose speakers to cast audio to")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Album art

    private var albumArt: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(red: 0.12, green: 0.16, blue: 0.22))  // #1F2937
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .overlay {
                if let url = nowPlaying?.coverArtURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        musicNotePlaceholder
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    musicNotePlaceholder
                }
            }
            .accessibilityLabel("Album art for \(nowPlaying?.title ?? "current track")")
            .accessibilityAddTraits(.isImage)
    }

    private var musicNotePlaceholder: some View {
        Image(systemName: "music.note")
            .font(.system(size: 48, weight: .medium))
            .foregroundStyle(Color.gray)
    }

    // MARK: - Song info

    private var songInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nowPlaying?.title ?? "Not Playing")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.color.title)
            Text(nowPlaying?.artist ?? "Unknown Artist")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.color.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nowPlaying?.title ?? "Not Playing") by \(nowPlaying?.artist ?? "Unknown Artist")")
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.color.divider)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.color.primary)
                        .frame(width: proxy.size.width * 0.55, height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text("2:14")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.color.muted)
                Spacer()
                Text("4:03")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.color.muted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback progress")
        .accessibilityValue("2 minutes 14 seconds of 4 minutes 3 seconds")
    }

    // MARK: - Transport controls

    private var transportControls: some View {
        HStack(spacing: 24) {
            Spacer()

            Button { sendCommand(.setShuffle(!(coordinator?.isShuffling ?? false))) } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(coordinator?.isShuffling == true
                                    ? Theme.color.primary : Theme.color.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shuffle")
            .accessibilityValue(coordinator?.isShuffling == true ? "On" : "Off")
            .accessibilityHint("Double tap to toggle shuffle")

            Button { sendCommand(.previous) } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.color.title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous track")

            Button { sendCommand(isPlaying ? .pause : .play) } label: {
                ZStack {
                    Circle()
                        .fill(Theme.color.primary)
                        .frame(width: 56, height: 56)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button { sendCommand(.next) } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.color.title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next track")

            Button { toggleRepeat() } label: {
                Image(systemName: repeatIconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(coordinator?.repeatMode != .off
                                    ? Theme.color.primary : Theme.color.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Repeat")
            .accessibilityValue({
                switch coordinator?.repeatMode {
                case .one: return "Repeat one"
                case .all: return "Repeat all"
                default: return "Off"
                }
            }())
            .accessibilityHint("Double tap to cycle repeat mode")

            Spacer()
        }
    }

    private var repeatIconName: String {
        switch coordinator?.repeatMode {
        case .one: return "repeat.1"
        default: return "repeat"
        }
    }

    private func toggleRepeat() {
        let current = coordinator?.repeatMode ?? .off
        let next: RepeatMode
        switch current {
        case .off: next = .all
        case .all: next = .one
        case .one: next = .off
        }
        sendCommand(.setRepeatMode(next))
    }

    // MARK: - Room volume section

    private var roomVolumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playing on \(totalRoomCount) rooms")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            // Coordinator room card
            roomVolumeCard(
                name: coordinatorRoomName,
                volumePercent: coordinator?.volumePercent ?? 0,
                isReachable: coordinator?.isReachable ?? true,
                isCoordinator: true
            )

            // Other member room cards
            ForEach(memberAccessories) { member in
                roomVolumeCard(
                    name: memberRoomName(member),
                    volumePercent: member.volumePercent ?? 0,
                    isReachable: member.isReachable,
                    isCoordinator: false
                )
            }

            // Names without matched accessories (fallback)
            let matchedNames = Set(memberAccessories.map { memberRoomName($0) })
            ForEach(otherRoomNames.filter { !matchedNames.contains($0) }, id: \.self) { name in
                roomVolumeCard(
                    name: name,
                    volumePercent: 0,
                    isReachable: true,
                    isCoordinator: false
                )
            }
        }
    }

    private func memberRoomName(_ accessory: Accessory) -> String {
        guard let roomID = accessory.roomID else { return accessory.name }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? accessory.name
    }

    @ViewBuilder
    private func roomVolumeCard(
        name: String,
        volumePercent: Int,
        isReachable: Bool,
        isCoordinator: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isReachable {
                // Connection lost state (pyUlJ)
                disconnectedRoomContent(name: name)
            } else {
                // Normal state (v5vpc)
                HStack {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.color.title)
                    Spacer()
                    Text("\(volumePercent)%")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.color.muted)
                    if !isCoordinator {
                        Button {
                            // Remove room from group placeholder
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Theme.color.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(name) from group")
                        .accessibilityHint("Removes this room from the multi-room audio group")
                    }
                }

                // Volume bar
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Theme.color.divider)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Theme.color.primary)
                            .frame(
                                width: proxy.size.width * CGFloat(volumePercent) / 100.0,
                                height: 4
                            )
                    }
                }
                .frame(height: 4)
                .accessibilityLabel("\(name) volume")
                .accessibilityValue("\(volumePercent) percent")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.color.cardFill)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Disconnected room (pyUlJ)

    @ViewBuilder
    private func disconnectedRoomContent(name: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.color.danger)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.color.title)
                Text("Disconnected")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.color.danger)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), disconnected")
        .accessibilityAddTraits(.isStaticText)

        HStack(spacing: 10) {
            Button {
                toast = .error("\(name) disconnected")
                // Retry connection placeholder
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .stroke(Theme.color.primary, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry connection to \(name)")
            .accessibilityHint("Attempts to reconnect to the disconnected speaker")

            Button {
                // Remove from group placeholder
            } label: {
                Text("Remove")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .stroke(Theme.color.muted, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(name) from group")
            .accessibilityHint("Removes the disconnected speaker from the audio group")
        }
    }

    // MARK: - Commands

    private func sendCommand(_ command: AccessoryCommand) {
        Task {
            do {
                try await registry.execute(command, on: coordinatorID)
            } catch {
                toast = .error(error.localizedDescription)
            }
        }
    }
}
