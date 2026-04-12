//
//  EmptyStateCard.swift
//  house connect
//
//  Shared presentational views for the "nothing here yet" state.
//  Matches Pencil nodes `ApNW6` (No Rooms Yet) and `375nI`
//  (No Speakers Found).
//
//  Both screens share the same skeleton: a big circular icon chip,
//  a bold title, a soft subtitle, a primary action button, and
//  some variant content below (feature bullets for rooms,
//  troubleshooting card + secondary link for speakers). Rather
//  than force the two into a single over-generalized component,
//  we factor out just the top half (`EmptyStateHero`) and let
//  each concrete view compose its own bottom half — the two
//  designs aren't similar enough below the CTA to justify a
//  template with more toggles.
//

import SwiftUI

// MARK: - Hero (shared between both empty states)

/// The top half that `NoRoomsEmptyState` and `NoSpeakersEmptyState`
/// share: icon chip → title → subtitle → primary CTA.
///
/// Designed to be dropped straight into a `VStack`, no `hcCard()`
/// wrapper — the concrete views compose their own cards around
/// the variant content below.
private struct EmptyStateHero: View {
    let systemIcon: String
    let title: String
    let subtitle: String
    let ctaLabel: String
    let ctaIcon: String?
    let ctaAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.color.iconChipFill)
                    .frame(width: 88, height: 88)
                Image(systemName: systemIcon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Theme.color.iconChipGlyph)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.color.title)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.color.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button(action: ctaAction) {
                HStack(spacing: 8) {
                    if let ctaIcon {
                        Image(systemName: ctaIcon)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(ctaLabel)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.color.primary)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - No Rooms Yet (Pencil ApNW6)

/// Full-screen empty state for when the provider registry returns
/// zero rooms. Used by `HomeDashboardView.roomsSection` and
/// `AllRoomsView.content` when the first-run state hits. The
/// primary CTA opens the add-room flow; when a provider isn't
/// even connected yet the caller should pass a CTA that jumps to
/// Settings instead ("Connect a Home" or similar).
struct NoRoomsEmptyState: View {
    let onAddRoom: () -> Void

    /// Feature bullets rendered below the CTA — three short
    /// lines describing what rooms unlock. Each has its own SF
    /// Symbol in a muted purple, matching Pencil `ApNW6`.
    private let features: [(icon: String, text: String)] = [
        ("mappin.and.ellipse", "Organize devices by location"),
        ("hand.tap.fill", "Control rooms with one tap"),
        ("sparkles", "Set scenes for each room")
    ]

    var body: some View {
        VStack(spacing: 28) {
            EmptyStateHero(
                systemIcon: "house.fill",
                title: "No Rooms Yet",
                subtitle: "Add your first room to start organizing your smart home devices",
                ctaLabel: "Add a Room",
                ctaIcon: "plus",
                ctaAction: onAddRoom
            )

            VStack(alignment: .leading, spacing: 14) {
                ForEach(features, id: \.text) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.color.primary)
                            .frame(width: 20)
                        Text(feature.text)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.color.subtitle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.space.screenHorizontal)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - No Speakers Found (Pencil 375nI)

/// Full-screen empty state for when the Sonos discovery sweep
/// returns zero speakers. Currently used by
/// `SonosRoomPickerSheet` when the anchor is the only speaker on
/// the network. `onScanAgain` kicks off a fresh discovery;
/// `onManualSetup` (optional) jumps to a manual setup flow that
/// doesn't exist yet but will eventually land alongside
/// `Oa5ev Device Pairing`.
struct NoSpeakersEmptyState: View {
    let onScanAgain: () -> Void
    var onManualSetup: (() -> Void)? = nil

    /// Troubleshooting bullets rendered in a white card below
    /// the CTA. Purpose is "user-actionable next steps" — we
    /// don't want to dump a stack trace, just three things a
    /// non-technical user can actually try.
    private let troubleshooting: [String] = [
        "Check speaker power and WiFi",
        "Ensure app and speakers are on same network",
        "Restart your router if issues persist"
    ]

    var body: some View {
        VStack(spacing: 24) {
            EmptyStateHero(
                systemIcon: "hifispeaker",
                title: "No Speakers Found",
                subtitle: "We couldn't find any compatible speakers on your network. Make sure your speakers are powered on and connected to WiFi.",
                ctaLabel: "Scan Again",
                ctaIcon: "arrow.clockwise",
                ctaAction: onScanAgain
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Troubleshooting")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                ForEach(troubleshooting, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Theme.color.iconChipFill)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        Text(tip)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.color.subtitle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .hcCard()

            if let onManualSetup {
                Button("Set up a speaker manually", action: onManualSetup)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.primary)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.space.screenHorizontal)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}
