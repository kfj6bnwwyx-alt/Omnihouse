//
//  T3MultiRoomNowPlayingView.swift
//  house connect
//
//  T3/Swiss port of the expanded now-playing screen for multi-room
//  speaker groups. Replaces the legacy `MultiRoomNowPlayingView`.
//  Hero album-art panel, transport row with 72pt orange play/pause,
//  tick-scale volume, and a per-speaker routing list.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3MultiRoomNowPlayingView: View {
    let coordinatorID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var groupVolume: Double = 0.5
    @State private var lastVolumeBucket: Int = -1
    @State private var toast: Toast?

    // MARK: - Derived state

    private var coordinator: Accessory? {
        registry.allAccessories.first { $0.id == coordinatorID }
    }

    private var isPlaying: Bool { coordinator?.playbackState == .playing }

    private var otherRoomNames: [String] {
        coordinator?.speakerGroup?.otherMemberNames ?? []
    }

    private var coordinatorRoomName: String {
        guard let coord = coordinator, let roomID = coord.roomID else {
            return coordinator?.name ?? "Speaker"
        }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == coord.id.provider }?
            .name ?? coord.name
    }

    private var memberAccessories: [Accessory] {
        registry.allAccessories.filter { acc in
            acc.category == .speaker && acc.id != coordinatorID &&
            otherRoomNames.contains { name in
                if acc.name == name { return true }
                if let roomID = acc.roomID,
                   let room = registry.allRooms.first(where: { $0.id == roomID && $0.provider == acc.id.provider }),
                   room.name == name { return true }
                return false
            }
        }
    }

    private var totalRoomCount: Int { 1 + otherRoomNames.count }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(
                        backLabel: "Zones",
                        rightLabel: coordinator?.id.provider.displayLabel.uppercased(),
                        showDot: isPlaying,
                        onBack: { dismiss() }
                    )

                    TTitle(title: coordinatorRoomName, isActive: isPlaying)

                    TSectionHead(title: "Now Playing", count: String(format: "%02d SPKRS", totalRoomCount))

                    // Hero art panel
                    albumArtPanel
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.bottom, 14)

                    // Track meta
                    VStack(alignment: .leading, spacing: 6) {
                        Text(coordinator?.nowPlaying?.title ?? "Not Playing")
                            .font(T3.inter(24, weight: .bold))
                            .foregroundStyle(T3.ink)
                            .lineLimit(2)
                        Text(coordinator?.nowPlaying?.artist ?? "—")
                            .font(T3.inter(16, weight: .regular))
                            .foregroundStyle(T3.sub)
                            .lineLimit(1)
                        if let album = coordinator?.nowPlaying?.album {
                            TLabel(text: album)
                        }
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.bottom, 20)

                    TRule()

                    // Transport
                    transportRow
                        .padding(.vertical, 24)

                    TRule()

                    // Group volume
                    TSectionHead(title: "Volume")
                    HStack(spacing: 14) {
                        volumeScale
                        Text("\(Int(groupVolume * 100))")
                            .font(T3.inter(22, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.bottom, 20)

                    TRule()

                    // Routing
                    TSectionHead(title: "Routing", count: String(format: "%02d", totalRoomCount))
                    speakerRow(
                        name: coordinatorRoomName,
                        accessory: coordinator,
                        isCoordinator: true
                    )
                    ForEach(memberAccessories) { member in
                        speakerRow(
                            name: memberRoomName(member),
                            accessory: member,
                            isCoordinator: false
                        )
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
        .onAppear {
            if let v = coordinator?.volumePercent {
                groupVolume = Double(v) / 100.0
            }
        }
    }

    // MARK: - Album art

    private var albumArtPanel: some View {
        ZStack {
            Rectangle()
                .fill(T3.panel)
                .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                .aspectRatio(1, contentMode: .fit)

            if let url = coordinator?.nowPlaying?.coverArtURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    musicPlaceholder
                }
                .clipped()
            } else {
                musicPlaceholder
            }
        }
    }

    private var musicPlaceholder: some View {
        VStack(spacing: 10) {
            T3IconImage(systemName: "music.note")
                .frame(width: 48, height: 48)
                .foregroundStyle(T3.ink)
            TDot(size: 10)
        }
    }

    // MARK: - Transport

    private var transportRow: some View {
        HStack(spacing: 28) {
            Spacer()

            Button { sendCommand(.previous) } label: {
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
            .accessibilityLabel("Previous track")

            Button {
                sendCommand(isPlaying ? .pause : .play)
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
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button { sendCommand(.next) } label: {
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
            .accessibilityLabel("Next track")

            Spacer()
        }
    }

    // MARK: - Volume scale

    private var volumeScale: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(0..<41, id: \.self) { i in
                    let f = Double(i) / 40.0
                    let major = i % 5 == 0
                    Rectangle()
                        .fill(f <= groupVolume ? T3.ink : T3.rule)
                        .frame(width: 1, height: major ? 14 : 7)
                        .position(x: f * geo.size.width, y: major ? 7 : 3.5)
                }
                TDot(size: 10).position(x: groupVolume * geo.size.width, y: 22)
            }
            .frame(width: geo.size.width, height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let v = max(0, min(1, value.location.x / geo.size.width))
                        groupVolume = v
                        let bucket = Int((v * 10).rounded(.down))
                        if bucket != lastVolumeBucket {
                            lastVolumeBucket = bucket
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        }
                    }
                    .onEnded { _ in
                        sendCommand(.setGroupVolume(Int(groupVolume * 100)))
                    }
            )
        }
        .frame(height: 28)
    }

    // MARK: - Speaker row

    private func speakerRow(name: String, accessory: Accessory?, isCoordinator: Bool) -> some View {
        let reachable = accessory?.isReachable ?? false
        let vol = accessory?.volumePercent ?? 0
        let muted = accessory?.isMuted ?? false

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if isCoordinator { TDot(size: 6) }
                Text(name)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                Spacer()
                if !reachable {
                    TLabel(text: "OFFLINE", color: T3.danger)
                } else {
                    TLabel(text: "\(vol)%")
                }
                if !isCoordinator, let accessory {
                    Button {
                        Task {
                            do {
                                try await registry.execute(.leaveSpeakerGroup, on: accessory.id)
                                toast = .success("\(name) removed")
                            } catch {
                                toast = .error("Couldn't remove \(name)")
                            }
                        }
                    } label: {
                        Text("×")
                            .font(T3.inter(18, weight: .regular))
                            .foregroundStyle(T3.danger)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(name) from group")
                }
            }

            if reachable, let accessory {
                HStack(spacing: 14) {
                    perSpeakerVolumeBar(percent: vol, accessoryID: accessory.id)
                    TToggle(isOn: Binding(
                        get: { muted },
                        set: { newValue in
                            Task { try? await registry.execute(.setMute(newValue), on: accessory.id) }
                        }
                    ), accessibilityLabel: "Mute \(name)")
                }
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
    }

    private func perSpeakerVolumeBar(percent: Int, accessoryID: AccessoryID) -> some View {
        // Simple tap-to-set bar; intentionally less interactive than the
        // group scale so the eye reads the primary control clearly.
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(T3.rule).frame(height: 2)
                Rectangle()
                    .fill(T3.ink)
                    .frame(width: geo.size.width * CGFloat(percent) / 100.0, height: 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let v = max(0, min(1, value.location.x / geo.size.width))
                        Task { try? await registry.execute(.setVolume(Int(v * 100)), on: accessoryID) }
                    }
            )
        }
        .frame(height: 10)
    }

    // MARK: - Helpers

    private func memberRoomName(_ accessory: Accessory) -> String {
        guard let roomID = accessory.roomID else { return accessory.name }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? accessory.name
    }

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
