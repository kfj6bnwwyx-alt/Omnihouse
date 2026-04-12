//
//  DevicePairingScanView.swift
//  house connect
//
//  "Searching for devices…" scanner screen (Pencil `Oa5ev`). Pushed
//  from the Sonos row of `ProviderChooserSheet` — it's the one
//  provider whose pair flow actually matches the Pencil design
//  (Sonos speakers auto-discover over Bonjour, so a radar animation
//  plus a list of "Ready to pair" rows maps cleanly).
//
//  HomeKit doesn't fit this pattern (Apple's setup sheet is
//  interactive and we can't render rows ourselves), and SmartThings
//  doesn't either (devices pair inside the ST app, not ours). Those
//  rows in the chooser keep their current behavior.
//
//  Layout from the comp:
//  ---------------------
//  - Top-aligned navigation header ("Add Device")
//  - Centered pulsing radar with a dot at the core (3 concentric
//    circles, each ~0.3s out of phase)
//  - "Searching for devices…" headline
//  - "Make sure your device is in pairing mode" subtitle
//  - Card list of discovered devices, each with icon + name +
//    "Ready to pair" (in green) + primary "Connect" button
//  - "Set up manually" link at bottom
//
//  Data source:
//  ------------
//  Sonos speakers are already in the registry the moment Bonjour
//  finds them, so there's no separate "pair" step — tapping
//  "Connect" on a row just navigates the user to that speaker's
//  detail screen (closes the whole chooser and dispatches a tab
//  switch). If the registry has zero Sonos speakers, the
//  `NoSpeakersEmptyState` shown elsewhere is repurposed here too.
//

import SwiftUI

struct DevicePairingScanView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    /// Drives the radar-pulse animation. Flipped once on first
    /// appearance; the three circles all animate against this
    /// single bool so they stay in phase with each other.
    @State private var isPulsing = false

    /// Controls the toast banner shown when the user taps "Connect"
    /// on an already-paired Sonos. Sonos doesn't have a real "pair"
    /// concept — the speaker is on the registry the moment we hear
    /// its Bonjour announcement — so tapping Connect mostly just
    /// acknowledges the user's intent. Toast tells them that in
    /// plain words so it doesn't feel like a no-op.
    @State private var toast: Toast?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                radar
                    .padding(.top, 16)
                headerCopy
                discoveredList
                manualSetupLink
                    .padding(.top, 4)
                Spacer(minLength: 16)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
            .padding(.bottom, 32)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationTitle("Add Device")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .task {
            // Kick one immediate rescan so the list is fresh.
            // We don't hold the UI on this — Sonos discovery is
            // already streaming in the background, so this is
            // mostly a "prove to the user we tried" refresh.
            if let sonos = registry.provider(for: .sonos) as? SonosProvider {
                await sonos.refresh()
            }
            withAnimation(
                .easeInOut(duration: 1.6).repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
    }

    // MARK: - Radar

    /// Three concentric pulsing circles + a center dot. The outer
    /// rings scale from 0.6→1.0 and fade from 0.4→0 over 1.6s on a
    /// repeating timeline — classic radar sweep feel.
    private var radar: some View {
        ZStack {
            pulseRing(scale: isPulsing ? 1.0 : 0.6, opacity: isPulsing ? 0.0 : 0.35, size: 180)
            pulseRing(scale: isPulsing ? 0.85 : 0.5, opacity: isPulsing ? 0.08 : 0.45, size: 180)
            pulseRing(scale: isPulsing ? 0.65 : 0.4, opacity: isPulsing ? 0.18 : 0.55, size: 180)
            Circle()
                .fill(Theme.color.primary)
                .frame(width: 14, height: 14)
        }
        .frame(width: 180, height: 180)
    }

    private func pulseRing(scale: CGFloat, opacity: Double, size: CGFloat) -> some View {
        Circle()
            .strokeBorder(Theme.color.primary, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
    }

    // MARK: - Header copy

    private var headerCopy: some View {
        VStack(spacing: 6) {
            Text("Searching for devices…")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.color.title)
            Text("Make sure your device is in pairing mode")
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.subtitle)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Discovered list

    /// Pulls the current Sonos accessories off the registry. We
    /// show reachable ones as "Ready to pair" (green), and
    /// unreachable ones still surface as rows because the user might
    /// be looking at exactly those.
    private var sonosSpeakers: [Accessory] {
        registry.allAccessories
            .filter { $0.id.provider == .sonos && $0.category == .speaker }
            .sorted { a, b in
                a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }

    @ViewBuilder
    private var discoveredList: some View {
        let speakers = sonosSpeakers
        if speakers.isEmpty {
            // Reuse the shared empty state so the visual vocabulary
            // stays consistent with the room-picker sheet's no-
            // speakers path. Re-runs the discovery sweep when tapped.
            NoSpeakersEmptyState(onScanAgain: {
                if let sonos = registry.provider(for: .sonos) as? SonosProvider {
                    Task { await sonos.refresh() }
                }
            })
        } else {
            VStack(spacing: 10) {
                ForEach(speakers) { speaker in
                    discoveredRow(for: speaker)
                }
            }
        }
    }

    /// One Pencil `Oa5ev` row: glyph + name + "Ready to pair" + CTA.
    private func discoveredRow(for accessory: Accessory) -> some View {
        HStack(spacing: 12) {
            IconChip(systemName: "hifispeaker.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(accessory.name)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text(accessory.isReachable ? "Ready to pair" : "Offline")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accessory.isReachable ? Theme.color.success : Theme.color.danger)
            }
            Spacer()
            Button {
                // Sonos speakers are already live on the registry, so
                // "Connect" is really just user acknowledgement. We
                // confirm with a toast so the tap isn't silent.
                toast = .success("\(accessory.name) is ready to use")
            } label: {
                Text("Connect")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.color.primary))
            }
            .buttonStyle(.plain)
            .disabled(!accessory.isReachable)
            .opacity(accessory.isReachable ? 1 : 0.5)
        }
        .hcCard()
    }

    // MARK: - Manual setup link

    /// "Set up manually" — the Pencil lifeline for devices the
    /// radar didn't catch. Currently a no-op (it's the same
    /// affordance as the existing `ProviderChooserSheet`, so we
    /// just pop back to it via dismiss).
    private var manualSetupLink: some View {
        Button {
            dismiss()
        } label: {
            Text("Set up manually")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.primary)
        }
        .buttonStyle(.plain)
    }
}
