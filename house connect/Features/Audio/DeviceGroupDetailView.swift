//
//  DeviceGroupDetailView.swift
//  house connect
//
//  Pencil `BUOyt` — Device Group Detail for bonded speaker sets
//  (e.g. Sonos Surround with Arc + Sub + Rears). Shows the primary
//  device header, now-playing card, group member list with per-member
//  volume, and group settings (master volume, ungroup).
//

import SwiftUI

struct DeviceGroupDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var toast: Toast?

    // MARK: - Derived state

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let acc = accessory, let roomID = acc.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == acc.id.provider }?
            .name
    }

    private var memberNames: [String] {
        accessory?.groupedParts ?? []
    }

    private var nowPlaying: NowPlaying? {
        accessory?.nowPlaying
    }

    private var isPlaying: Bool {
        accessory?.playbackState == .playing
    }

    private var isOn: Bool {
        accessory?.isOn ?? false
    }

    private var groupVolume: Int {
        accessory?.speakerGroup?.groupVolume ?? accessory?.volumePercent ?? 0
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                customHeader
                nowPlayingCard
                groupMembersSection
                groupSettingsSection
                Spacer(minLength: 32)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
            .padding(.top, 8)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }

    // MARK: - Header

    private var customHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(Theme.color.cardFill)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .overlay(
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.color.title)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text(accessory?.name ?? "Speaker Group")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.color.title)

                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.color.muted)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            powerToggle
        }
        .padding(.vertical, 4)
    }

    private var headerSubtitle: String {
        let room = roomName ?? "Unknown Room"
        let count = memberNames.count
        return "\(room) · \(count) device\(count == 1 ? "" : "s")"
    }

    private var powerToggle: some View {
        Button {
            sendCommand(.setPower(!isOn))
        } label: {
            Capsule()
                .fill(isOn ? Theme.color.primary : Theme.color.divider)
                .frame(width: 44, height: 26)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .padding(2)
                }
                .animation(.easeInOut(duration: 0.2), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Power")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("Double tap to turn \(isOn ? "off" : "on") the speaker group")
    }

    // MARK: - Now Playing card

    private var nowPlayingCard: some View {
        HStack(spacing: 12) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.20, green: 0.22, blue: 0.28))
                .frame(width: 56, height: 56)
                .overlay {
                    if let url = nowPlaying?.coverArtURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "music.note")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(nowPlaying?.title ?? "Not Playing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Text(nowPlaying?.artist ?? "Unknown Artist")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)

                Text("Playing on all speakers")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            Button {
                sendCommand(isPlaying ? .pause : .play)
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(Color(red: 0.12, green: 0.14, blue: 0.20))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing: \(nowPlaying?.title ?? "Not Playing") by \(nowPlaying?.artist ?? "Unknown Artist")")
    }

    // MARK: - Group Members section

    private var groupMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group Members")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            ForEach(Array(memberNames.enumerated()), id: \.offset) { index, name in
                memberRow(name: name, isPrimary: index == 0)
            }
        }
    }

    @ViewBuilder
    private func memberRow(name: String, isPrimary: Bool) -> some View {
        let memberAccessory = registry.allAccessories.first {
            $0.category == .speaker && $0.name == name
        }
        let volume = memberAccessory?.volumePercent
        let deviceType = memberDeviceType(name: name)

        HStack(spacing: 12) {
            // Accent-tinted speaker icon chip
            Circle()
                .fill(Theme.color.iconChipFill)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "hifispeaker.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.color.primary)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.color.title)

                    if isPrimary {
                        Text("Primary")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Theme.color.primary)
                            )
                    }
                }

                Text(memberSubtitle(deviceType: deviceType, volume: volume))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.color.muted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
                .accessibilityHidden(true)
        }
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)\(isPrimary ? ", primary" : ""), \(memberSubtitle(deviceType: deviceType, volume: volume))")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens device details")
    }

    private func memberDeviceType(name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("arc") || lowered.contains("beam") || lowered.contains("ray") {
            return "Soundbar"
        } else if lowered.contains("sub") {
            return "Subwoofer"
        } else if lowered.contains("rear") || lowered.contains("surround") {
            return "Surround Speaker"
        }
        return "Speaker"
    }

    private func memberSubtitle(deviceType: String, volume: Int?) -> String {
        if let vol = volume {
            return "\(deviceType) · Vol \(vol)%"
        }
        return deviceType
    }

    // MARK: - Group Settings section

    private var groupSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            // Group Volume row
            HStack(spacing: 12) {
                IconChip(systemName: "speaker.wave.2.fill", size: 36)

                Text("Group Volume \(groupVolume)%")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color.title)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color.muted)
                    .accessibilityHidden(true)
            }
            .hcCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Group Volume")
            .accessibilityValue("\(groupVolume) percent")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens group volume controls")

            // Ungroup Devices row
            Button {
                sendCommand(.leaveSpeakerGroup)
            } label: {
                HStack(spacing: 12) {
                    IconChip(
                        systemName: "link.badge.plus",
                        size: 36,
                        fill: Theme.color.danger.opacity(0.12),
                        glyph: Theme.color.danger
                    )

                    Text("Ungroup Devices")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.color.danger)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.color.muted)
                }
                .hcCard()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ungroup devices")
            .accessibilityHint("Separates all speakers in this group back into individual devices")
        }
    }

    // MARK: - Commands

    private func sendCommand(_ command: AccessoryCommand) {
        Task {
            do {
                try await registry.execute(command, on: accessoryID)
            } catch {
                toast = .error(error.localizedDescription)
            }
        }
    }
}
