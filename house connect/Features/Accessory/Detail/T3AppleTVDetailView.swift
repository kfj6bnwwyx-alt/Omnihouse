//
//  T3AppleTVDetailView.swift
//  house connect
//
//  T3/Swiss detail for Apple TV devices exposed via Home Assistant's
//  core `apple_tv` integration. Each Apple TV surfaces as a single
//  `media_player.*` entity with transport services, a `source_list`
//  populated from installed apps, and now-playing metadata including
//  `entity_picture` artwork.
//
//  Shape of the screen (top to bottom):
//    - Header + title (matches Frame TV / Speaker detail cadence)
//    - Now-playing hero (artwork + title + artist + progress) or
//      a Standby placeholder when nothing is playing
//    - Transport row: Previous / Play-Pause / Next
//    - App launcher — horizontally-scrolling chips sourced from
//      `source_list`, firing `media_player.select_source` on tap
//    - Power toggle (`turn_on` / `turn_off`)
//
//  All commands route through `ProviderRegistry.execute` via
//  `T3ActionFeedback.perform` for haptic + toast feedback, matching
//  the pattern established by the Lock / Light / Speaker detail views.
//

import SwiftUI

struct T3AppleTVDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var isSending: Bool = false
    @State private var toast: Toast?

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var isOn: Bool { accessory?.isOn ?? false }
    private var isReachable: Bool { accessory?.isReachable ?? true }
    private var controlsEnabled: Bool { isReachable && !isSending }

    private var isPlaying: Bool {
        accessory?.playbackState == .playing
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    var body: some View {
        Group {
            if !isReachable {
                T3DeviceOfflineView(accessoryID: accessoryID)
            } else {
                content
            }
        }
        .toast($toast)
    }

    private var content: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(
                        backLabel: roomName != nil ? "Room" : "Devices",
                        rightLabel: statusLabel,
                        showDot: isOn,
                        onBack: { dismiss() }
                    )

                    TTitle(
                        title: accessory?.name ?? "Apple TV",
                        subtitle: roomName,
                        isActive: isOn
                    )

                    TSectionHead(
                        title: "Apple TV",
                        count: statusLabel
                    )

                    heroPanel
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.bottom, 18)

                    TRule()

                    // Transport row
                    TSectionHead(title: "Transport")
                    transportRow
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 18)

                    TRule()

                    // App launcher
                    TSectionHead(title: "Apps")
                    appLauncher
                        .padding(.bottom, 18)

                    TRule()

                    // Stats strip
                    TSectionHead(title: "Current State")
                    HStack(spacing: 18) {
                        statCell(label: "App", value: accessory?.currentSource ?? "—")
                        statCell(label: "State", value: playbackLabel)
                        statCell(label: "Volume", value: accessory.flatMap { $0.volumePercent.map { "\($0)%" } } ?? "—")
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 18)

                    TRule()

                    // Power toggle — Apple TV supports wake-from-sleep
                    // via HA, so `turn_on` works end-to-end.
                    Button {
                        send(.setPower(!isOn),
                             successMessage: !isOn ? "Power on" : "Power off")
                    } label: {
                        HStack {
                            T3IconImage(systemName: "power")
                                .frame(width: 16, height: 16)
                                .foregroundStyle(T3.ink)
                            Text(isOn ? "Turn off" : "Turn on")
                                .font(T3.inter(14, weight: .medium))
                                .foregroundStyle(T3.ink)
                            Spacer()
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.t3Row)
                    .disabled(!controlsEnabled)

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var statusLabel: String {
        if !isOn { return "STANDBY" }
        if isPlaying { return "PLAYING" }
        return "ON"
    }

    private var playbackLabel: String {
        switch accessory?.playbackState {
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .stopped: return "Stopped"
        case .transitioning: return "Loading"
        default: return isOn ? "Idle" : "Standby"
        }
    }

    // MARK: - Hero now-playing panel

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                artworkView
                    .frame(width: 88, height: 88)
                    .clipped()
                    .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text(heroTitle)
                        .font(T3.inter(18, weight: .bold))
                        .foregroundStyle(T3.ink)
                        .lineLimit(2)
                    Text(heroSubtitle)
                        .font(T3.inter(14, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineLimit(1)
                    if let progress = progressFraction {
                        progressBar(progress)
                            .padding(.top, 6)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            Rectangle()
                .fill(T3.panel)
                .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
        )
        .padding(.top, 12)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let url = accessory?.nowPlaying?.coverArtURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    artworkPlaceholder
                }
            }
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            Rectangle().fill(T3.page)
            T3IconImage(systemName: "tv")
                .frame(width: 28, height: 28)
                .foregroundStyle(T3.sub)
        }
    }

    private var heroTitle: String {
        if let title = accessory?.nowPlaying?.title { return title }
        if isOn {
            if let src = accessory?.currentSource { return src }
            return "Idle"
        }
        return "Standby"
    }

    private var heroSubtitle: String {
        if let artist = accessory?.nowPlaying?.artist { return artist }
        if let album = accessory?.nowPlaying?.album { return album }
        if isOn { return accessory?.currentSource ?? "No media" }
        return "Tap a button to wake"
    }

    private var progressFraction: Double? {
        // HA reports position + duration on the attributes. We only
        // have them via `Capability.mediaPosition` / `mediaDuration`
        // on the accessory — look them up.
        guard let accessory else { return nil }
        var pos: Double?
        var dur: Double?
        for cap in accessory.capabilities {
            if case .mediaPosition(let s) = cap { pos = s }
            if case .mediaDuration(let s) = cap { dur = s }
        }
        guard let pos, let dur, dur > 0 else { return nil }
        return min(1.0, max(0.0, pos / dur))
    }

    private func progressBar(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(T3.rule).frame(height: 2)
                Rectangle().fill(T3.ink)
                    .frame(width: geo.size.width * fraction, height: 2)
            }
        }
        .frame(height: 2)
    }

    // MARK: - Transport

    private var transportRow: some View {
        HStack(spacing: 1) {
            transportButton(icon: "backward.fill", label: "PREV") {
                send(.previous, successMessage: nil)
            }
            transportButton(
                icon: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "PAUSE" : "PLAY"
            ) {
                send(isPlaying ? .pause : .play,
                     successMessage: isPlaying ? "Paused" : "Playing")
            }
            transportButton(icon: "forward.fill", label: "NEXT") {
                send(.next, successMessage: nil)
            }
        }
        .opacity(controlsEnabled ? 1.0 : 0.5)
        .disabled(!controlsEnabled)
    }

    private func transportButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                T3IconImage(systemName: icon)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(T3.ink)
                Text(label)
                    .font(T3.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(T3.sub)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(T3.panel)
            .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - App launcher

    @ViewBuilder
    private var appLauncher: some View {
        if let sources = accessory?.sourceList, !sources.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sources, id: \.self) { source in
                        Button {
                            send(.selectSource(source),
                                 successMessage: "Launched · \(source)")
                        } label: {
                            Text(source)
                                .font(T3.inter(13, weight: .medium))
                                .foregroundStyle(source == accessory?.currentSource ? T3.page : T3.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Rectangle()
                                        .fill(source == accessory?.currentSource ? T3.ink : T3.panel)
                                        .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!controlsEnabled)
                    }
                }
                .padding(.horizontal, T3.screenPadding)
            }
            .opacity(controlsEnabled ? 1.0 : 0.5)
        } else {
            Text("No apps reported — launch with the Apple TV remote")
                .font(T3.mono(10))
                .tracking(1.2)
                .foregroundStyle(T3.sub)
                .padding(.horizontal, T3.screenPadding)
        }
    }

    // MARK: - Command helper

    /// Route an `AccessoryCommand` through the registry with haptics,
    /// toast feedback, and an `isSending` guard. Matches the pattern
    /// used by T3FrameTVDetailView / T3SpeakerDetailView.
    private func send(_ command: AccessoryCommand, successMessage: String?) {
        guard !isSending else { return }
        isSending = true
        Task { @MainActor in
            await T3ActionFeedback.perform(
                action: { try await registry.execute(command, on: accessoryID) },
                toast: { toast = .error("Couldn't reach the Apple TV") },
                errorDescription: "AppleTV"
            )
            if let msg = successMessage, toast?.kind != .error {
                toast = .success(msg)
            }
            isSending = false
        }
    }

    // MARK: - Stat cell

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: label)
            Text(value)
                .font(T3.inter(16, weight: .medium))
                .foregroundStyle(T3.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
