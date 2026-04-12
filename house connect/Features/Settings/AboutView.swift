//
//  AboutView.swift
//  house connect
//
//  "About" screen reached from Settings → Support → About.
//  Shows app version, build info, ecosystem badges, and links to
//  acknowledgments / third-party licenses. Follows the same card-based
//  visual language as the rest of the app.
//

import SwiftUI

struct AboutView: View {
    @Environment(ProviderRegistry.self) private var registry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                header
                    .padding(.top, 8)
                appInfoCard
                ecosystemBadges
                linksSection
                footerNote
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        SettingsSubpageHeader(title: "About", subtitle: "House Connect")
    }

    // MARK: - App info card

    private var appInfoCard: some View {
        VStack(spacing: 20) {
            // App icon placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.color.primary, Theme.color.primaryPressed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "house.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("House Connect app icon")
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("House Connect")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.color.title)
                Text(versionString)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
            .accessibilityElement(children: .combine)

            Text("Unify your smart home. Control HomeKit, SmartThings, Nest, and Sonos devices from a single, beautiful app.")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .hcCard()
    }

    // MARK: - Ecosystem badges

    private var ecosystemBadges: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ECOSYSTEMS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.subtitle)
                .tracking(0.8)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(registry.providers, id: \.id) { provider in
                    HStack(spacing: 14) {
                        IconChip(
                            systemName: iconForProvider(provider.id),
                            size: 40,
                            fill: provider.authorizationState == .authorized
                                ? Theme.color.primary.opacity(0.12)
                                : Theme.color.iconChipFill,
                            glyph: provider.authorizationState == .authorized
                                ? Theme.color.primary
                                : Theme.color.iconChipGlyph
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName)
                                .font(Theme.font.cardTitle)
                                .foregroundStyle(Theme.color.title)
                            Text(statusLabel(for: provider.authorizationState))
                                .font(Theme.font.cardSubtitle)
                                .foregroundStyle(
                                    provider.authorizationState == .authorized
                                        ? Theme.color.success
                                        : Theme.color.subtitle
                                )
                        }
                        Spacer()
                        Text("\(provider.accessories.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.color.muted)
                        Text("devices")
                            .font(Theme.font.cardSubtitle)
                            .foregroundStyle(Theme.color.muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(provider.displayName), \(statusLabel(for: provider.authorizationState)), \(provider.accessories.count) devices")
                }
            }
            .hcCard(padding: 0)
        }
    }

    // MARK: - Links section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RESOURCES")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.subtitle)
                .tracking(0.8)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                linkRow(
                    icon: "doc.text.fill",
                    title: "Privacy Policy",
                    subtitle: "How we handle your data"
                )
                linkRow(
                    icon: "scroll.fill",
                    title: "Terms of Service",
                    subtitle: "Usage agreement"
                )
                linkRow(
                    icon: "heart.fill",
                    title: "Acknowledgments",
                    subtitle: "Open-source libraries"
                )
                linkRow(
                    icon: "envelope.fill",
                    title: "Contact Support",
                    subtitle: "Get help or send feedback"
                )
            }
            .hcCard(padding: 0)
        }
    }

    private func linkRow(icon: String, title: String, subtitle: String) -> some View {
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
            Image(systemName: "arrow.up.right")
                .foregroundStyle(Theme.color.muted)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isLink)
    }

    // MARK: - Footer

    private var footerNote: some View {
        VStack(spacing: 4) {
            Text("Made with ❤️ for smart home enthusiasts")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.muted)
            Text("© 2026 House Connect. All rights reserved.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.color.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "Version \(v) (\(b))"
    }

    private func iconForProvider(_ id: ProviderID) -> String {
        switch id {
        case .homeKit: return "homekit"
        case .smartThings: return "cpu"
        case .nest: return "thermometer"
        case .sonos: return "hifispeaker.fill"
        }
    }

    private func statusLabel(for state: ProviderAuthorizationState) -> String {
        switch state {
        case .authorized: return "Connected"
        case .denied: return "Access Denied"
        case .notDetermined: return "Not Set Up"
        case .restricted: return "Restricted"
        case .unavailable: return "Unavailable"
        }
    }
}
