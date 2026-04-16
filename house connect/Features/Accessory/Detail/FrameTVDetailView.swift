//
//  FrameTVDetailView.swift
//  house connect
//
//  Bespoke detail screen for the Samsung Frame TV. Matches Pencil node
//  `GrzJY`. Now data-driven from Home Assistant `media_player` entities
//  via the unified Capability model.
//
//  HA Samsung TV integration exposes:
//    - Power on/off (state: on/off/standby)
//    - Source selection (source + source_list attributes)
//    - Volume control (volume_level, is_volume_muted)
//    - Now playing (media_title, media_artist, entity_picture)
//    - Art Mode (appears as a source in the source_list)
//
//  The view reads all values reactively from the Accessory's capabilities
//  and routes commands through the ProviderRegistry.
//

import SwiftUI

struct FrameTVDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(MergedDeviceLookup.self) private var mergedLookup
    @AppStorage("devices.preferredProvider") private var preferredProviderRaw: String = ProviderID.homeKit.rawValue

    @State private var errorMessage: String?
    @State private var isExecuting = false

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            if let accessory {
                ScrollView {
                    VStack(spacing: 20) {
                        DeviceDetailHeader(
                            title: accessory.name,
                            subtitle: roomName,
                            isOn: accessory.isOn,
                            onTogglePower: { on in
                                Task { await send(.setPower(on)) }
                            }
                        )
                        .padding(.top, 8)

                        if !accessory.isReachable {
                            offlineBanner
                        }

                        if let error = errorMessage {
                            errorBanner(error)
                        }

                        heroCard(for: accessory)
                        statusRow(for: accessory)
                        inputSourceCard(for: accessory)
                        remoteButtonsCard(for: accessory)
                        volumeCard(for: accessory)
                        RemoveDeviceSection(accessoryID: accessoryID)
                    }
                    .padding(.horizontal, Theme.space.screenHorizontal)
                    .padding(.bottom, 24)
                }
            } else {
                ContentUnavailableView(
                    "TV unavailable",
                    systemImage: "tv.slash",
                    description: Text("This device is no longer reported by its provider.")
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hero (art preview / now playing)

    private func heroCard(for accessory: Accessory) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.18), Color(white: 0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

            // Starry-night gradient ambiance
            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.32, blue: 0.58).opacity(0.55),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )

            // Show now-playing info or art mode placeholder
            if let np = accessory.nowPlaying, np.title != nil || np.artist != nil {
                nowPlayingOverlay(np, accessory: accessory)
            } else if isArtMode(accessory) {
                artModeOverlay
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "tv")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                    if accessory.isOn == false {
                        Text("TV Off")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    private func nowPlayingOverlay(_ np: NowPlaying, accessory: Accessory) -> some View {
        VStack(spacing: 8) {
            // Cover art from HA entity_picture (if available via REST proxy)
            if let url = np.coverArtURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let title = np.title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            if let artist = np.artist {
                Text(artist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding()
    }

    private var artModeOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.82, blue: 0.38),
                            Color(red: 0.62, green: 0.72, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Art Mode")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    // MARK: - Status row

    private func statusRow(for accessory: Accessory) -> some View {
        HStack(spacing: 12) {
            // Power status
            HStack(spacing: 6) {
                Circle()
                    .fill(accessory.isOn == true ? Color.green : Color.gray)
                    .frame(width: 7, height: 7)
                Text(statusText(for: accessory))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.color.iconChipFill))

            Spacer(minLength: 8)

            // Current source
            if let source = accessory.currentSource {
                Text(source)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.color.subtitle)
                    .lineLimit(1)
            }
        }
        .hcCard()
    }

    private func statusText(for accessory: Accessory) -> String {
        if isArtMode(accessory) { return "Art Mode · On" }
        if accessory.isOn == true {
            if let source = accessory.currentSource {
                return source
            }
            return "On"
        }
        return "Off"
    }

    // MARK: - Input source selector

    private func inputSourceCard(for accessory: Accessory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Input Source")
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)

            if let sources = accessory.sourceList, !sources.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sources, id: \.self) { source in
                            sourceChip(source, isSelected: source == accessory.currentSource)
                        }
                    }
                }
            } else {
                Text("No sources available")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.color.muted)
            }
        }
        .hcCard()
    }

    private func sourceChip(_ source: String, isSelected: Bool) -> some View {
        Button {
            Task { await send(.selectSource(source)) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: sourceIcon(source))
                    .font(.system(size: 13, weight: .semibold))
                Text(source)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : Theme.color.subtitle)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Theme.color.primary : Theme.color.iconChipFill)
            )
        }
        .buttonStyle(.plain)
        .disabled(isExecuting || !(accessory?.isReachable ?? false))
    }

    // MARK: - Remote buttons

    private func remoteButtonsCard(for accessory: Accessory) -> some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            circleButton(icon: "power", tint: Theme.color.primary) {
                Task { await send(.setPower(!(accessory.isOn ?? false))) }
            }
            circleButton(icon: "speaker.wave.1.fill") {
                Task {
                    let current = accessory.volumePercent ?? 50
                    await send(.setVolume(max(0, current - 10)))
                }
            }
            circleButton(icon: "speaker.wave.3.fill") {
                Task {
                    let current = accessory.volumePercent ?? 50
                    await send(.setVolume(min(100, current + 10)))
                }
            }
            circleButton(icon: accessory.isMuted == true ? "speaker.slash.fill" : "speaker.fill") {
                Task { await send(.setMute(!(accessory.isMuted ?? false))) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .hcCard(padding: 0)
    }

    private func circleButton(
        icon: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tint ?? Theme.color.iconChipFill)
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint == nil ? Theme.color.title : .white)
            }
        }
        .buttonStyle(.plain)
        .disabled(isExecuting || !(accessory?.isReachable ?? false))
    }

    // MARK: - Volume card

    private func volumeCard(for accessory: Accessory) -> some View {
        VStack(spacing: 14) {
            if let vol = accessory.volumePercent {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.color.primary)
                    Text("Volume")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.color.title)
                    Spacer()
                    Text("\(vol)%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.color.subtitle)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Volume, \(vol) percent")
            }
        }
        .hcCard()
    }

    // MARK: - Offline / error banners

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
            Text("TV offline — controls disabled")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.orange)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.color.title)
            Spacer()
            Button { errorMessage = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.color.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
    }

    // MARK: - Helpers

    private func isArtMode(_ accessory: Accessory) -> Bool {
        guard let source = accessory.currentSource else { return false }
        let lower = source.lowercased()
        return lower.contains("art") || lower.contains("ambient")
    }

    private func sourceIcon(_ source: String) -> String {
        let lower = source.lowercased()
        if lower.contains("hdmi") { return "cable.connector" }
        if lower.contains("airplay") { return "airplayvideo" }
        if lower.contains("art") || lower.contains("ambient") { return "photo.artframe" }
        if lower.contains("tv") || lower.contains("dtv") { return "antenna.radiowaves.left.and.right" }
        if lower.contains("usb") { return "externaldrive.fill" }
        if lower.contains("bluetooth") { return "wave.3.right" }
        if lower.contains("wifi") || lower.contains("screen mirror") { return "wifi" }
        return "rectangle.on.rectangle"
    }

    // MARK: - Command dispatch

    private func send(_ command: AccessoryCommand) async {
        isExecuting = true
        defer { isExecuting = false }
        do {
            if let merged = mergedLookup.merged(for: accessoryID) {
                let preferred = ProviderID(rawValue: preferredProviderRaw) ?? .homeKit
                try await registry.execute(command, onMerged: merged, preferredProvider: preferred)
            } else {
                try await registry.execute(command, on: accessoryID)
            }
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
