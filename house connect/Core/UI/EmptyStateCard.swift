//
//  EmptyStateCard.swift
//  house connect
//
//  Shared presentational views for the "nothing here yet" state.
//  Matches Pencil nodes `ApNW6` (No Rooms Yet) and `375nI`
//  (No Speakers Found). Converted to T3/Swiss design system:
//  flat CTA button, T3 tokens, TRule-based troubleshooting rows,
//  no rounded cards.
//

import SwiftUI

// MARK: - Hero (shared between both empty states)

/// Top block shared by both empty states: large icon → title →
/// subtitle → full-width CTA. Dropped straight into a VStack —
/// callers compose variant content below.
private struct EmptyStateHero: View {
    let systemIcon: String
    let title: String
    let subtitle: String
    let ctaLabel: String
    let ctaIcon: String?
    let ctaAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Large icon — T3 style: no background chip, just ink glyph
            T3IconImage(systemName: systemIcon)
                .frame(width: 48, height: 48)
                .foregroundStyle(T3.ink)

            VStack(spacing: 10) {
                Text(title)
                    .font(T3.inter(28, weight: .medium))
                    .tracking(-0.8)
                    .foregroundStyle(T3.ink)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Flat full-width CTA button — T3.ink fill, T3.page text
            Button(action: ctaAction) {
                HStack(spacing: 8) {
                    if let ctaIcon {
                        T3IconImage(systemName: ctaIcon)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                    }
                    Text(ctaLabel.uppercased())
                        .font(T3.mono(11))
                        .tracking(2)
                }
                .foregroundStyle(T3.page)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(T3.ink)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - No Rooms Yet (Pencil ApNW6)

/// Empty state for when the provider registry returns zero rooms.
struct NoRoomsEmptyState: View {
    let onAddRoom: () -> Void

    private let features: [(icon: String, text: String)] = [
        ("mappin.and.ellipse", "Organize devices by location"),
        ("hand.tap.fill",      "Control rooms with one tap"),
        ("sparkles",           "Set scenes for each room")
    ]

    var body: some View {
        VStack(spacing: 32) {
            EmptyStateHero(
                systemIcon: "house.fill",
                title: "No rooms yet",
                subtitle: "Add your first room to start organizing your smart home devices.",
                ctaLabel: "Add a room",
                ctaIcon: "plus",
                ctaAction: onAddRoom
            )

            // Feature bullets — T3IconImage + TLabel
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.element.text) { i, feature in
                    HStack(spacing: 14) {
                        T3IconImage(systemName: feature.icon)
                            .frame(width: 14, height: 14)
                            .foregroundStyle(T3.sub)
                            .accessibilityHidden(true)
                        Text(feature.text)
                            .font(T3.inter(13, weight: .regular))
                            .foregroundStyle(T3.sub)
                        Spacer()
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) {
                        if i == features.count - 1 { TRule() }
                    }
                }
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - No Speakers Found (Pencil 375nI)

/// Empty state for when the Sonos discovery sweep returns zero speakers.
struct NoSpeakersEmptyState: View {
    let onScanAgain: () -> Void
    var onManualSetup: (() -> Void)? = nil

    private let troubleshooting: [String] = [
        "Check speaker power and Wi-Fi",
        "Ensure app and speakers are on the same network",
        "Restart your router if issues persist"
    ]

    var body: some View {
        VStack(spacing: 28) {
            EmptyStateHero(
                systemIcon: "hifispeaker",
                title: "No speakers found",
                subtitle: "We couldn't find any compatible speakers on your network. Make sure your speakers are powered on and connected.",
                ctaLabel: "Scan again",
                ctaIcon: "arrow.clockwise",
                ctaAction: onScanAgain
            )

            // Troubleshooting rows — TRule hairlines
            VStack(alignment: .leading, spacing: 0) {
                TSectionHead(title: "Troubleshooting")
                ForEach(Array(troubleshooting.enumerated()), id: \.element) { i, tip in
                    HStack(spacing: 14) {
                        TDot(size: 5)
                            .accessibilityHidden(true)
                        Text(tip)
                            .font(T3.inter(13, weight: .regular))
                            .foregroundStyle(T3.sub)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 11)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) {
                        if i == troubleshooting.count - 1 { TRule() }
                    }
                }
            }

            if let onManualSetup {
                Button("Set up a speaker manually", action: onManualSetup)
                    .font(T3.inter(13, weight: .medium))
                    .foregroundStyle(T3.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}
