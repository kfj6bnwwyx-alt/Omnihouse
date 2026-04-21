//
//  MultiRoomNowPlayingView.swift
//  house connect
//
//  Pencil `v5vpc` / `co524` / `pyUlJ` — Expanded Now Playing screen
//  for multi-room audio groups. Shows album art, track metadata,
//  transport controls, a progress bar, and per-room volume rows.
//  Converted to T3/Swiss design system.
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

    private var nowPlaying: NowPlaying? { coordinator?.nowPlaying }
    private var isPlaying: Bool { coordinator?.playbackState == .playing }

    private var otherRoomNames: [String] {
        coordinator?.speakerGroup?.otherMemberNames ?? []
    }

    private var coordinatorRoomName: String {
        guard let coordinator, let roomID = coordinator.roomID else {
            return coordinator?.name ?? "Speaker"
        }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == coordinator.id.provider }?
            .name ?? coordinator.name
    }

    private var allRoomNames: [String] { [coordinatorRoomName] + otherRoomNames }
    private var totalRoomCount: Int { allRoomNames.count }

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
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Audio Zones", onBack: { dismiss() })

                    TTitle(
                        title: nowPlaying?.title ?? "Not playing.",
                        subtitle: nowPlaying?.artist.map { $0.uppercased() } ?? "NO SOURCE"
                    )

                    // Album art — T3 ink rectangle with music note placeholder
                    albumArt

                    // Progress bar
                    TSectionHead(title: "Progress")
                    progressBar

                    // Transport controls
                    transportRow
                        .padding(.vertical, 24)

                    TRule()

                    // Room volumes
                    TSectionHead(
                        title: "Playing on",
                        count: "\(totalRoomCount) ROOM\(totalRoomCount == 1 ? "" : "S")"
                    )

                    // Coordinator room
                    roomVolumeRow(
                        name: coordinatorRoomName,
                        volumePercent: coordinator?.volumePercent ?? 0,
                        isReachable: coordinator?.isReachable ?? true,
                        isCoordinator: true
                    )

                    // Other members
                    ForEach(memberAccessories) { member in
                        roomVolumeRow(
                            name: memberRoomName(member),
                            volumePercent: member.volumePercent ?? 0,
                            isReachable: member.isReachable,
                            isCoordinator: false,
                            member: member
                        )
                    }

                    // Names without matched accessories
                    let matchedNames = Set(memberAccessories.map { memberRoomName($0) })
                    ForEach(otherRoomNames.filter { !matchedNames.contains($0) }, id: \.self) { name in
                        roomVolumeRow(
                            name: name,
                            volumePercent: 0,
                            isReachable: true,
                            isCoordinator: false
                        )
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }

    // MARK: - Album art

    private var albumArt: some View {
        ZStack {
            Rectangle()
                .fill(T3.ink)
                .frame(height: 200)
            if let url = nowPlaying?.coverArtURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                } placeholder: {
                    T3IconImage(systemName: "music.note")
                        .frame(width: 48, height: 48)
                        .foregroundStyle(T3.sub)
                }
            } else {
                TDot(size: 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 18)
        .accessibilityLabel("Album art for \(nowPlaying?.title ?? "current track")")
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(T3.rule)
                        .frame(height: 2)
                    Rectangle()
                        .fill(T3.accent)
                        .frame(width: proxy.size.width * 0.55, height: 2)
                }
            }
            .frame(height: 2)

            HStack {
                Text("2:14")
                    .font(T3.mono(11))
                    .foregroundStyle(T3.sub)
                    .monospacedDigit()
                Spacer()
                Text("4:03")
                    .font(T3.mono(11))
                    .foregroundStyle(T3.sub)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback progress: 2 minutes 14 seconds of 4 minutes 3 seconds")
    }

    // MARK: - Transport row

    private var transportRow: some View {
        HStack(spacing: 20) {
            Spacer()

            // Shuffle
            Button { sendCommand(.setShuffle(!(coordinator?.isShuffling ?? false))) } label: {
                T3IconImage(systemName: "shuffle")
                    .frame(width: 20, height: 20)
                    .foregroundStyle(coordinator?.isShuffling == true ? T3.accent : T3.sub)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shuffle")
            .accessibilityValue(coordinator?.isShuffling == true ? "On" : "Off")

            // Previous
            Button { sendCommand(.previous) } label: {
                T3IconImage(systemName: "backward.fill")
                    .frame(width: 22, height: 22)
                    .foregroundStyle(T3.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous track")

            // Play/Pause — 72px ink circle
            Button { sendCommand(isPlaying ? .pause : .play) } label: {
                Circle()
                    .fill(T3.ink)
                    .frame(width: 72, height: 72)
                    .overlay(
                        T3IconImage(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 24, height: 24)
                            .foregroundStyle(T3.page)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            // Next
            Button { sendCommand(.next) } label: {
                T3IconImage(systemName: "forward.fill")
                    .frame(width: 22, height: 22)
                    .foregroundStyle(T3.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next track")

            // Repeat
            Button { toggleRepeat() } label: {
                T3IconImage(systemName: repeatIconName)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(coordinator?.repeatMode != .off ? T3.accent : T3.sub)
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

            Spacer()
        }
    }

    private var repeatIconName: String {
        coordinator?.repeatMode == .one ? "repeat.1" : "repeat"
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

    // MARK: - Room volume rows

    @ViewBuilder
    private func roomVolumeRow(
        name: String,
        volumePercent: Int,
        isReachable: Bool,
        isCoordinator: Bool,
        member: Accessory? = nil,
        isLast: Bool = false
    ) -> some View {
        if !isReachable {
            disconnectedRow(name: name, isLast: isLast)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(name)
                        .font(T3.inter(14, weight: .medium))
                        .foregroundStyle(T3.ink)
                    Spacer()
                    Text("\(volumePercent)%")
                        .font(T3.mono(11))
                        .foregroundStyle(T3.sub)
                        .monospacedDigit()
                    if !isCoordinator {
                        Button {
                            Task {
                                let speakerID = member?.id ?? AccessoryID(provider: .sonos, nativeID: name)
                                do {
                                    try await registry.execute(.leaveSpeakerGroup, on: speakerID)
                                    toast = .success("\(name) removed from group")
                                } catch {
                                    toast = .error("Failed to remove \(name)")
                                }
                            }
                        } label: {
                            T3IconImage(systemName: "xmark")
                                .frame(width: 12, height: 12)
                                .foregroundStyle(T3.sub)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                        .accessibilityLabel("Remove \(name) from group")
                    }
                }

                // Volume tick
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(T3.rule)
                            .frame(height: 2)
                        Rectangle()
                            .fill(T3.ink)
                            .frame(
                                width: proxy.size.width * CGFloat(volumePercent) / 100.0,
                                height: 2
                            )
                    }
                }
                .frame(height: 2)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { if isLast { TRule() } }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(name) volume \(volumePercent) percent")
        }
    }

    @ViewBuilder
    private func disconnectedRow(name: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(T3.danger)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    T3IconImage(systemName: "wifi.slash")
                        .frame(width: 14, height: 14)
                        .foregroundStyle(T3.danger)
                        .accessibilityHidden(true)
                    Text(name)
                        .font(T3.inter(14, weight: .medium))
                        .foregroundStyle(T3.ink)
                }
                Text("Disconnected")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.danger)

                HStack(spacing: 10) {
                    Button {
                        Task {
                            if let sonos = registry.provider(for: .sonos) as? SonosProvider {
                                await sonos.refreshTopologyAndRebuild()
                                toast = .success("Refreshed — checking \(name)")
                            }
                        }
                    } label: {
                        Text("RETRY")
                            .font(T3.mono(9))
                            .tracking(1.2)
                            .foregroundStyle(T3.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(Rectangle().stroke(T3.sub, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retry connection to \(name)")

                    Button {
                        Task {
                            let speakerID = AccessoryID(provider: .sonos, nativeID: name)
                            do {
                                try await registry.execute(.leaveSpeakerGroup, on: speakerID)
                                toast = .success("\(name) removed")
                            } catch {
                                toast = .error("Can't remove — speaker offline")
                            }
                        }
                    } label: {
                        Text("REMOVE")
                            .font(T3.mono(9))
                            .tracking(1.2)
                            .foregroundStyle(T3.sub)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(name) from group")
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), disconnected")
    }

    private func memberRoomName(_ accessory: Accessory) -> String {
        guard let roomID = accessory.roomID else { return accessory.name }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? accessory.name
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
