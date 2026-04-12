//
//  SonosBondedGroupDetailView.swift
//  house connect
//
//  Bespoke detail screen for bonded Sonos sets (home theater surround,
//  stereo pairs, soundbar + sub). Matches Pencil node `BUOyt` — "Sonos
//  Surround / Living Room · 4 devices" with a group members list and
//  a group settings footer.
//
//  Bonded vs grouped, in Sonos vocabulary:
//
//  - A BONDED set is a single logical device made up of multiple hardware
//    speakers wired together as channels of one playback target: Arc
//    (LCR) + Sub + two Sonos Ones (L/R surrounds) for a 5.1 setup, or a
//    stereo pair of Fives. Bonds are configured in the Sonos app and
//    persist across power cycles.
//
//  - A (CASUAL) SPEAKER GROUP is a transient party-mode grouping: the
//    user drops "Kitchen" into the "Living Room" now-playing, and they
//    both start streaming the same thing. Breakable in one tap.
//
//  Our provider surfaces bonded sets as a SINGLE Accessory with
//  `groupedParts: [String]` naming the bonded members. The regular
//  `SonosPlayerDetailView` already renders that accessory fine, but
//  Pencil wants a first-class layout for bonded sets — that's this
//  file. `DeviceDetailView` routes Sonos speakers with non-empty
//  `groupedParts` here instead of `SonosPlayerDetailView`.
//
//  Scope of this screen:
//
//  - Read-only list of the bonded parts. We can't rename, re-channel,
//    or unbind them from here — Sonos only exposes bonding topology
//    writes through its native app. "Ungroup Devices" therefore opens a
//    confirmation that points the user at the Sonos app; we don't
//    surprise-delete their home theater.
//  - One transport (the whole set shares playback) and one volume (the
//    whole set shares master volume) — fed by the anchor accessory's
//    `.playback` / `.volume` capabilities.
//  - A now-playing card mirroring the regular player, so the user
//    doesn't feel like they lost features by having a bonded layout.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SonosBondedGroupDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    // MARK: - State

    @State private var errorMessage: String?
    @State private var toast: Toast?
    /// Slider-drag draft for the master volume. Matches the pattern used
    /// in `SonosPlayerDetailView.volumeCard` so drag-to-commit feels the
    /// same here — the slider tracks finger position until the provider
    /// catches up, then snaps to the authoritative reading.
    @State private var volumeDraft: Double?
    @State private var volumeDebounce: Task<Void, Never>?
    /// Confirmation for the "Ungroup Devices" destructive tap. We don't
    /// actually unbind anything (Sonos only supports that via its own
    /// app) — we just tell the user so, one tap away from the CTA.
    @State private var showingUngroupConfirm = false

    // MARK: - Data lookups

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    /// Subtitle line under the title: "Living Room · 4 devices".
    /// Drops the room fragment when unavailable so the string reads
    /// cleanly either way ("4 devices").
    private func subtitle(for accessory: Accessory) -> String {
        let count = accessory.groupedParts?.count ?? 0
        let countLabel = "\(count) device\(count == 1 ? "" : "s")"
        if let room = roomName, !room.isEmpty {
            return "\(room) · \(countLabel)"
        }
        return countLabel
    }

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            if let accessory {
                ScrollView {
                    VStack(spacing: 20) {
                        DeviceDetailHeader(
                            title: accessory.name,
                            subtitle: subtitle(for: accessory),
                            isOn: accessory.isOn,
                            onTogglePower: { on in
                                Task { await send(.setPower(on), accessory: accessory) }
                            }
                        )
                        .padding(.top, 8)

                        nowPlayingCard(for: accessory)
                        groupMembersSection(for: accessory)
                        groupSettingsSection(for: accessory)
                    }
                    .padding(.horizontal, Theme.space.screenHorizontal)
                    .padding(.bottom, 32)
                }
            } else {
                ContentUnavailableView(
                    "Group unavailable",
                    systemImage: "hifispeaker.2"
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
        .alert("Sonos",
               isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }),
               actions: { Button("OK") { errorMessage = nil } },
               message: { Text(errorMessage ?? "") })
        .confirmationDialog(
            "Ungroup Devices",
            isPresented: $showingUngroupConfirm,
            titleVisibility: .visible
        ) {
            Button("Open Sonos App", role: .none) {
                // The Sonos app registers `sonos://` but Apple-signed
                // third-parties can't always open it reliably from
                // other apps. Fallback to the App Store page is the
                // safest universal path.
                if let url = URL(string: "https://apps.apple.com/app/sonos/id1488977981") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Bonded sets (home theater / stereo pair) can only be unbonded from the Sonos app. House Connect will rejoin the set automatically once you return.")
        }
    }

    // MARK: - Now playing

    /// Condensed now-playing strip: small cover art tile + title/artist
    /// lines + play/pause button. The bonded set shares one transport,
    /// so this drives the whole rig.
    private func nowPlayingCard(for accessory: Accessory) -> some View {
        HStack(spacing: 14) {
            coverArtTile(for: accessory)
            VStack(alignment: .leading, spacing: 4) {
                Text(accessory.nowPlaying?.title ?? "Nothing playing")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text(accessory.nowPlaying?.artist ?? "—")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .lineLimit(1)
                Text("Playing on all speakers")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.color.primary)
            }
            Spacer()
            playPauseButton(for: accessory)
        }
        .hcCard()
    }

    /// 56pt square thumbnail. Tries the cover art URL; falls back to a
    /// musical-note glyph on the chip-fill background so the card
    /// still reads as "media" when nothing's playing.
    private func coverArtTile(for accessory: Accessory) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black)
                .frame(width: 56, height: 56)
            if let url = accessory.nowPlaying?.coverArtURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func playPauseButton(for accessory: Accessory) -> some View {
        let isPlaying = accessory.playbackState == .playing
        return Button {
            Task {
                await send(isPlaying ? .pause : .play, accessory: accessory)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.color.iconChipFill)
                    .frame(width: 40, height: 40)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.color.primary)
            }
        }
        .buttonStyle(.plain)
        .disabled(accessory.capability(of: .playback) == nil)
    }

    // MARK: - Group Members list

    private func groupMembersSection(for accessory: Accessory) -> some View {
        let parts = accessory.groupedParts ?? []
        return VStack(alignment: .leading, spacing: 10) {
            Text("Group Members")
                .font(Theme.font.sectionHeader)
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 10) {
                ForEach(Array(parts.enumerated()), id: \.offset) { pair in
                    memberRow(
                        name: pair.element,
                        role: bondedRole(index: pair.offset, total: parts.count),
                        isPrimary: pair.offset == 0,
                        volumePercent: pair.offset == 0 ? accessory.volumePercent : nil
                    )
                }
            }
        }
    }

    /// Best-effort role heuristic for bonded parts based on position
    /// inside `groupedParts`. Sonos' topology naming is consistent
    /// enough that index 0 = primary (soundbar or left-of-pair),
    /// index 1 = sub on home theater / right-of-pair on stereo,
    /// indices 2–3 = surround channels. Good enough for the Pencil
    /// layout. Swap for a real `ChannelMap` enum if we ever parse
    /// SONOS's `<HTSatChanMapSet>` property in the discovery sweep.
    private func bondedRole(index: Int, total: Int) -> String {
        if total == 2 {
            return index == 0 ? "Left · Stereo Pair" : "Right · Stereo Pair"
        }
        switch index {
        case 0: return "Soundbar"
        case 1: return "Subwoofer"
        case 2: return "Left Surround"
        case 3: return "Right Surround"
        default: return "Channel \(index + 1)"
        }
    }

    /// One row in the group members card. Matches the Pencil rows:
    /// icon chip, name + role subtitle, optional PRIMARY badge, volume
    /// readout for the anchor, chevron on the trailing edge.
    private func memberRow(
        name: String,
        role: String,
        isPrimary: Bool,
        volumePercent: Int?
    ) -> some View {
        HStack(spacing: 12) {
            IconChip(systemName: "hifispeaker.fill")
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                        .lineLimit(1)
                    if isPrimary {
                        Text("Primary")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.color.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Theme.color.iconChipFill)
                            )
                    }
                }
                if let volumePercent {
                    Text("\(role) · Vol \(volumePercent)%")
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                        .lineLimit(1)
                } else {
                    Text(role)
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
        }
        .hcCard()
    }

    // MARK: - Group Settings

    /// Footer card. Group Volume slider (bonded sets have ONE master
    /// volume, so this is just the anchor's regular volume capability)
    /// and the "Ungroup Devices" destructive call-to-action.
    private func groupSettingsSection(for accessory: Accessory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Group Settings")
                .font(Theme.font.sectionHeader)
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                groupVolumeRow(for: accessory)
                Divider().padding(.leading, 56)
                ungroupRow
            }
            .hcCard(padding: 0)
        }
    }

    private func groupVolumeRow(for accessory: Accessory) -> some View {
        let liveVolume = Double(accessory.volumePercent ?? 0)
        let binding = Binding<Double>(
            get: { volumeDraft ?? liveVolume },
            set: { newValue in
                volumeDraft = newValue
                scheduleVolumeCommit(to: Int(newValue), accessory: accessory)
            }
        )
        return HStack(spacing: 12) {
            IconChip(systemName: "speaker.wave.2.fill")
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Group Volume")
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Spacer()
                    Text("\(Int(volumeDraft ?? liveVolume))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.color.subtitle)
                }
                Slider(value: binding, in: 0...100)
                    .tint(Theme.color.primary)
                    .disabled(accessory.capability(of: .volume) == nil)
            }
        }
        .padding(.horizontal, Theme.space.cardPadding)
        .padding(.vertical, 14)
    }

    private var ungroupRow: some View {
        Button {
            showingUngroupConfirm = true
        } label: {
            HStack(spacing: 12) {
                IconChip(systemName: "rectangle.portrait.and.arrow.right")
                Text("Ungroup Devices")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.danger)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color.muted)
            }
            .padding(.horizontal, Theme.space.cardPadding)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Commands

    /// Debounced commit for the master volume slider. Same shape as
    /// `SonosPlayerDetailView.scheduleGroupVolumeCommit` but on the
    /// anchor's plain `.setVolume` command because bonded sets share
    /// master volume through the anchor directly — no GroupRendering
    /// indirection needed.
    private func scheduleVolumeCommit(to value: Int, accessory: Accessory) {
        volumeDebounce?.cancel()
        volumeDebounce = Task { [value] in
            try? await Task.sleep(for: .milliseconds(60))
            if Task.isCancelled { return }
            await send(.setVolume(value), accessory: accessory)
            await MainActor.run { volumeDraft = nil }
        }
    }

    private func send(_ command: AccessoryCommand, accessory: Accessory) async {
        do {
            try await registry.execute(command, on: accessory.id)
        } catch {
            errorMessage = "\(accessory.name): \(error)"
        }
    }
}
