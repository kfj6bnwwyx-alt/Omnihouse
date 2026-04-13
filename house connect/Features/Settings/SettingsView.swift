//
//  SettingsView.swift
//  house connect
//
//  The SETTINGS tab. Rebuilt to match the Pencil design (node RlG8v):
//    - Profile card at top
//    - Sectioned rows with lavender icon chips (HOME / PREFERENCES / SUPPORT)
//    - Provider management still lives here — collapsed into the "Home
//      Settings" destination so the top-level list stays clean.
//
//  Provider-management detail (previous Form-based SettingsView contents)
//  now lives at `ProvidersSettingsView` — reached via Home Settings →
//  "Connections". That keeps the Pencil-matching top level uncluttered
//  while preserving every capability Phase 2a / 3a shipped.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(ProviderRegistry.self) private var registry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                Text("Settings")
                    .font(Theme.font.screenTitle)
                    .foregroundStyle(Theme.color.title)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)

                profileCard
                homeSection
                preferencesSection
                supportSection

                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(for: SettingsDestination.self) { dest in
            settingsDestinationView(for: dest)
        }
    }

    // MARK: - Sections

    private var homeSection: some View {
        section(title: "HOME") {
            NavigationLink(value: SettingsDestination.providers) {
                SettingsRow(
                    icon: "house.fill",
                    title: "Connections",
                    subtitle: providerSummary
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: SettingsDestination.networkTopology) {
                SettingsRow(
                    icon: "wifi",
                    title: "Network & Hubs",
                    subtitle: "Topology, Wi-Fi, bridges"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: SettingsDestination.rooms) {
                SettingsRow(
                    icon: "square.grid.2x2.fill",
                    title: "Rooms & Zones",
                    subtitle: "Organize your spaces"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: SettingsDestination.audioZones) {
                SettingsRow(
                    icon: "hifispeaker.2.fill",
                    title: "Audio Zones",
                    subtitle: "Multi-room speaker map"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var preferencesSection: some View {
        section(title: "PREFERENCES") {
            NavigationLink(value: SettingsDestination.notifications) {
                SettingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Alerts, sounds, badges"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: SettingsDestination.scenes) {
                SettingsRow(
                    icon: "sparkles",
                    title: "Scenes",
                    subtitle: "Cross-ecosystem presets"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: SettingsDestination.appearance) {
                SettingsRow(
                    icon: "paintbrush.fill",
                    title: "Appearance",
                    subtitle: "Theme, app icon, display"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var supportSection: some View {
        section(title: "SUPPORT") {
            NavigationLink(value: SettingsDestination.helpFAQ) {
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & FAQ",
                    subtitle: "Guides, troubleshooting"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: SettingsDestination.about) {
                SettingsRow(
                    icon: "info.circle.fill",
                    title: "About",
                    subtitle: versionString
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func settingsDestinationView(for dest: SettingsDestination) -> some View {
        switch dest {
        case .providers: ProvidersSettingsView()
        case .rooms: AllRoomsView()
        case .scenes: ScenesListView()
        case .audioZones: AudioZonesMapView()
        case .networkTopology: DeviceNetworkTopologyView()
        case .about: AboutView()
        case .helpFAQ: HelpFAQView()
        case .notifications: NotificationPreferencesView()
        case .appearance: AppearanceView()
        }
    }

    // MARK: - Building blocks

    /// Profile card — reads the device owner name from the system and
    /// derives the avatar initial. The card is informational (no tap
    /// target) since there's no account system to navigate to yet.
    private var profileCard: some View {
        let ownerName = Self.cleanedDeviceOwner(UIDevice.current.name)
        let initial = ownerName.first.map(String.init) ?? "?"

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.color.primary)
                    .frame(width: 52, height: 52)
                Text(initial)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(ownerName)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Text("Local account")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
        }
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ownerName), Local account")
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.subtitle)
                .tracking(0.8)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                content()
            }
            .hcCard(padding: 0)
        }
    }

    // MARK: - Helpers

    private var providerSummary: String {
        let connected = registry.providers.filter {
            $0.authorizationState == .authorized
        }.count
        return "\(connected) of \(registry.providers.count) connected"
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "Version \(v) (\(b))"
    }

    /// Strips common possessive device-name suffixes across localizations.
    /// English: "Brent's iPhone" → "Brent". Also handles curly / straight
    /// apostrophes and the most common device types.
    static func cleanedDeviceOwner(_ raw: String) -> String {
        let suffixes = [
            "'s iPhone", "'s iPad", "'s iPod",
            "\u{2019}s iPhone", "\u{2019}s iPad", "\u{2019}s iPod",  // curly '
            "'s Apple Watch", "\u{2019}s Apple Watch",
            "'s MacBook", "\u{2019}s MacBook",
            "'s Mac", "\u{2019}s Mac",
            " iPhone", " iPad",   // fallback if no possessive
        ]
        var name = raw
        for suffix in suffixes {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        return name.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Row

/// Flat settings row: leading icon chip, title, subtitle, trailing chevron.
/// Stacked inside a single `.hcCard(padding: 0)` so a group of rows reads
/// as one card with internal dividers.
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            IconChip(systemName: icon, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Text(subtitle)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.color.muted)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(isDisabled ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    /// Convenience to mark a row as non-interactive without wiring a real
    /// disabled state — just a visual cue that this destination isn't
    /// implemented yet. Rows wrapped in `NavigationLink` use the link's
    /// own styling; these unwrapped rows represent "coming soon" stubs.
    func disabled() -> some View {
        var copy = self
        copy.isDisabled = true
        return copy
    }
}

// MARK: - Destinations

enum SettingsDestination: Hashable {
    case providers
    case rooms
    case scenes
    case audioZones
    case networkTopology
    case about
    case helpFAQ
    case notifications
    case appearance
}
