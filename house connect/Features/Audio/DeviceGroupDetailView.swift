//
//  DeviceGroupDetailView.swift
//  house connect
//
//  Pencil `BUOyt` — Device Group Detail for bonded speaker sets
//  (Sonos Surround with Arc + Sub + Rears). Shows the primary device
//  header, now-playing card, group member list with per-member volume,
//  and group settings. Converted to T3/Swiss design system.
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

    private var memberNames: [String]  { accessory?.groupedParts ?? [] }
    private var nowPlaying:  NowPlaying? { accessory?.nowPlaying }
    private var isPlaying:   Bool { accessory?.playbackState == .playing }
    private var isOn:        Bool { accessory?.isOn ?? false }
    private var groupVolume: Int  {
        accessory?.speakerGroup?.groupVolume ?? accessory?.volumePercent ?? 0
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(
                        backLabel: roomName ?? "Room",
                        rightLabel: "SONOS",
                        onBack: { dismiss() }
                    )

                    // Name + status eyebrow
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            if isOn { TDot(size: 8) }
                            TLabel(text: isOn ? "On" : "Off")
                        }
                        Text(accessory?.name ?? "Speaker Group")
                            .font(T3.inter(42, weight: .medium))
                            .tracking(-1.4)
                            .foregroundStyle(T3.ink)
                            .lineLimit(2)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                    TRule()

                    // Now-playing card
                    nowPlayingCard

                    TRule()

                    // Group members
                    TSectionHead(
                        title: "Group members",
                        count: "\(memberNames.count)"
                    )
                    ForEach(Array(memberNames.enumerated()), id: \.offset) { i, name in
                        memberRow(name: name, isPrimary: i == 0, isLast: i == memberNames.count - 1)
                    }

                    // Group settings
                    TSectionHead(title: "Group settings")
                    groupVolumeRow
                    ungroupRow

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }

    // MARK: - Now-playing card

    private var nowPlayingCard: some View {
        HStack(spacing: 16) {
            // Album art — T3 ink square
            ZStack {
                Rectangle()
                    .fill(T3.ink)
                    .frame(width: 56, height: 56)
                if let url = nowPlaying?.coverArtURL {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        T3IconImage(systemName: "music.note")
                            .frame(width: 18, height: 18)
                            .foregroundStyle(T3.sub)
                    }
                    .frame(width: 56, height: 56)
                    .clipped()
                } else {
                    TDot(size: 10)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                TLabel(text: "Now playing")
                Text(nowPlaying?.title ?? "Not Playing")
                    .font(T3.inter(16, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                Text(nowPlaying?.artist ?? "Unknown Artist")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                sendCommand(isPlaying ? .pause : .play)
            } label: {
                T3IconImage(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 20, height: 20)
                    .foregroundStyle(T3.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Now playing: \(nowPlaying?.title ?? "Not Playing") by \(nowPlaying?.artist ?? "Unknown Artist")"
        )
    }

    // MARK: - Member row

    @ViewBuilder
    private func memberRow(name: String, isPrimary: Bool, isLast: Bool) -> some View {
        let memberAccessory = registry.allAccessories.first {
            $0.category == .speaker && $0.name == name
        }
        let volume = memberAccessory?.volumePercent
        let deviceType = memberDeviceType(name: name)

        HStack(spacing: 14) {
            T3IconImage(systemName: "hifispeaker.fill")
                .frame(width: 16, height: 16)
                .foregroundStyle(isPrimary ? T3.accent : T3.sub)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(T3.inter(14, weight: .medium))
                        .foregroundStyle(T3.ink)
                    if isPrimary {
                        Text("PRIMARY")
                            .font(T3.mono(8))
                            .tracking(1.2)
                            .foregroundStyle(T3.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .overlay(Rectangle().stroke(T3.accent, lineWidth: 1))
                    }
                }
                TLabel(text: memberSubtitle(deviceType: deviceType, volume: volume).uppercased())
            }

            Spacer()

            T3IconImage(systemName: "chevron.right")
                .frame(width: 10, height: 10)
                .foregroundStyle(T3.sub)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(name)\(isPrimary ? ", primary" : ""), \(memberSubtitle(deviceType: deviceType, volume: volume))"
        )
        .accessibilityHint("Opens device details")
    }

    private func memberDeviceType(name: String) -> String {
        let l = name.lowercased()
        if l.contains("arc") || l.contains("beam") || l.contains("ray") { return "Soundbar" }
        if l.contains("sub") { return "Subwoofer" }
        if l.contains("rear") || l.contains("surround") { return "Surround Speaker" }
        return "Speaker"
    }

    private func memberSubtitle(deviceType: String, volume: Int?) -> String {
        volume.map { "\(deviceType) · Vol \($0)%" } ?? deviceType
    }

    // MARK: - Group settings rows

    private var groupVolumeRow: some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: "speaker.wave.2.fill")
                .frame(width: 16, height: 16)
                .foregroundStyle(T3.ink)
                .frame(width: 28)
            Text("Group Volume")
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.ink)
            Spacer()
            Text("\(groupVolume)%")
                .font(T3.mono(11))
                .foregroundStyle(T3.sub)
                .monospacedDigit()
            T3IconImage(systemName: "chevron.right")
                .frame(width: 10, height: 10)
                .foregroundStyle(T3.sub)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Group Volume")
        .accessibilityValue("\(groupVolume) percent")
        .accessibilityHint("Opens group volume controls")
    }

    private var ungroupRow: some View {
        Button {
            sendCommand(.leaveSpeakerGroup)
        } label: {
            HStack(spacing: 14) {
                T3IconImage(systemName: "link.badge.plus")
                    .frame(width: 16, height: 16)
                    .foregroundStyle(T3.danger)
                    .frame(width: 28)
                Text("Ungroup devices")
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.danger)
                Spacer()
                T3IconImage(systemName: "chevron.right")
                    .frame(width: 10, height: 10)
                    .foregroundStyle(T3.sub)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { TRule() }
        }
        .buttonStyle(.plain)
        .padding(.top, 24)
        .accessibilityLabel("Ungroup devices")
        .accessibilityHint("Separates all speakers back into individual devices")
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
