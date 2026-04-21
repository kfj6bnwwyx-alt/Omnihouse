//
//  T3SonosBondedGroupDetailView.swift
//  house connect
//
//  T3/Swiss bonded-Sonos-set detail — flat member list with role badges,
//  group volume + transport, destructive unbind footer. Config-oriented
//  (no now-playing hero / cover art) since bonding topology is the topic.
//
//  Bonded sets (home theater, stereo pair, soundbar + sub) are modeled
//  as a single Accessory with `groupedParts: [String]`; bonds themselves
//  are configured from the Sonos app, so "Unbind group" opens a dialog
//  that points the user there rather than surprise-deleting their set.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3SonosBondedGroupDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage: String?
    @State private var volumeDraft: Double?
    @State private var volumeDebounce: Task<Void, Never>?
    @State private var showingUnbindConfirm = false

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    private var memberCount: Int { accessory?.groupedParts?.count ?? 0 }

    private var sectionCountLabel: String {
        let speakers = "\(memberCount) SPEAKER\(memberCount == 1 ? "" : "S")"
        if let room = roomName, !room.isEmpty {
            return "\(speakers) · \(room.uppercased())"
        }
        return speakers
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            if let accessory {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        THeader(
                            backLabel: roomName ?? "Room",
                            rightLabel: "SONOS",
                            onBack: { dismiss() }
                        )

                        TTitle(
                            title: accessory.name,
                            subtitle: nil,
                            isActive: accessory.playbackState == .playing
                        )

                        TSectionHead(title: "BONDED GROUP", count: sectionCountLabel)

                        // Member list
                        ForEach(Array((accessory.groupedParts ?? []).enumerated()), id: \.offset) { pair in
                            memberRow(
                                name: pair.element,
                                role: bondedRole(index: pair.offset, total: memberCount),
                                isPrimary: pair.offset == 0,
                                isLast: pair.offset == memberCount - 1
                            )
                        }

                        TRule()

                        TSectionHead(title: "Group controls")

                        transportRow(for: accessory)

                        TRule()

                        volumeRow(for: accessory)

                        TRule()

                        // Unbind footer
                        Button {
                            showingUnbindConfirm = true
                        } label: {
                            HStack {
                                TLabel(text: "Unbind group", color: T3.danger)
                                Spacer()
                                T3IconImage(systemName: "rectangle.portrait.and.arrow.right")
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(T3.danger)
                            }
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 18)
                        }
                        .buttonStyle(.t3Row)
                        .accessibilityLabel("Unbind group")
                        .accessibilityHint("Opens instructions to unbind in the Sonos app")

                        TRule()

                        Spacer(minLength: 120)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    TLabel(text: "Group unavailable")
                    Text("This bonded group is no longer reported by Sonos.")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .multilineTextAlignment(.center)
                }
                .padding(T3.screenPadding)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Sonos",
               isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }),
               actions: { Button("OK") { errorMessage = nil } },
               message: { Text(errorMessage ?? "") })
        .confirmationDialog(
            "Unbind group",
            isPresented: $showingUnbindConfirm,
            titleVisibility: .visible
        ) {
            #if os(iOS)
            Button("Open Sonos app") {
                if let url = URL(string: "https://apps.apple.com/app/sonos/id1488977981") {
                    UIApplication.shared.open(url)
                }
            }
            #endif
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Bonded sets (home theater / stereo pair) can only be unbonded from the Sonos app. House Connect will rejoin automatically once you return.")
        }
    }

    // MARK: - Member row

    private func memberRow(name: String, role: String, isPrimary: Bool, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            // Role badge — mono uppercase, compact
            Text(roleBadge(role))
                .font(T3.mono(10))
                .tracking(1.4)
                .foregroundStyle(isPrimary ? T3.accent : T3.sub)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                Text(role)
                    .font(T3.mono(10))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(T3.sub)
                    .lineLimit(1)
            }

            Spacer()

            if isPrimary { TDot(size: 6) }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) {
            if isLast { TRule() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(role)\(isPrimary ? ", primary" : "")")
    }

    /// Short role code for the leading badge column.
    private func roleBadge(_ role: String) -> String {
        if role.localizedCaseInsensitiveContains("left") { return "L" }
        if role.localizedCaseInsensitiveContains("right") { return "R" }
        if role.localizedCaseInsensitiveContains("sub") { return "SUB" }
        if role.localizedCaseInsensitiveContains("soundbar") { return "BAR" }
        return "CH"
    }

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

    // MARK: - Transport

    private func transportRow(for accessory: Accessory) -> some View {
        let isPlaying = accessory.playbackState == .playing
        return HStack(spacing: 16) {
            Button {
                Task { await send(isPlaying ? .pause : .play, accessory: accessory) }
            } label: {
                HStack(spacing: 10) {
                    T3IconImage(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 18, height: 18)
                        .foregroundStyle(isPlaying ? T3.accent : T3.ink)
                    Text(isPlaying ? "Pause" : "Play")
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                }
            }
            .buttonStyle(.plain)
            .disabled(accessory.capability(of: .playback) == nil)

            Spacer()

            if let np = accessory.nowPlaying, let t = np.title {
                Text(t)
                    .font(T3.mono(11))
                    .tracking(1.0)
                    .foregroundStyle(T3.sub)
                    .textCase(.uppercase)
                    .lineLimit(1)
            } else {
                TLabel(text: "Idle")
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 16)
    }

    // MARK: - Volume

    private func volumeRow(for accessory: Accessory) -> some View {
        let liveVolume = Double(accessory.volumePercent ?? 0)
        let binding = Binding<Double>(
            get: { volumeDraft ?? liveVolume },
            set: { newValue in
                volumeDraft = newValue
                scheduleVolumeCommit(to: Int(newValue), accessory: accessory)
            }
        )
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                TLabel(text: "Group volume")
                Spacer()
                Text("\(Int(volumeDraft ?? liveVolume))%")
                    .font(T3.mono(11))
                    .tracking(1.2)
                    .foregroundStyle(T3.ink)
                    .monospacedDigit()
            }
            Slider(value: binding, in: 0...100)
                .tint(T3.accent)
                .disabled(accessory.capability(of: .volume) == nil)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 16)
    }

    // MARK: - Commands

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
