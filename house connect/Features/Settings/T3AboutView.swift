//
//  T3AboutView.swift
//  house connect
//
//  Settings → Support → About. T3 rename of AboutView 2026-04-18 with
//  accessibility polish: Dynamic Type clamp, a11y labels/traits on the
//  tappable links, and `nil` counts on the sections that don't have one.
//

import SwiftUI

struct T3AboutView: View {
    @Environment(ProviderRegistry.self) private var registry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "About.", subtitle: "House Connect")

                // App
                TSectionHead(title: "App", count: nil)
                infoRow(icon: "house", title: "House Connect", sub: versionString)
                infoRow(icon: "pencil", title: "Unified smart home control",
                        sub: "ONE APP · EVERY ECOSYSTEM")
                TRule()

                // Ecosystems
                TSectionHead(title: "Ecosystems",
                             count: String(format: "%02d", registry.providers.count))
                ForEach(Array(registry.providers.enumerated()), id: \.element.id) { i, provider in
                    ecosystemRow(index: i, provider: provider,
                                 isLast: i == registry.providers.count - 1)
                }

                // Resources
                TSectionHead(title: "Resources", count: nil)
                linkRow(icon: "shield-check", title: "Privacy Policy",
                        sub: "How we handle your data", url: "https://example.com/privacy")
                linkRow(icon: "pencil", title: "Terms of Service",
                        sub: "Usage agreement", url: "https://example.com/terms")
                linkRow(icon: "sparkles", title: "Acknowledgments",
                        sub: "Open-source libraries", url: "https://example.com/oss")
                linkRow(icon: "mail", title: "Contact support",
                        sub: "Get help or send feedback",
                        url: "mailto:support@example.com", isLast: true)

                // Foot
                VStack(spacing: 4) {
                    TLabel(text: "MADE FOR SMART HOME ENTHUSIASTS")
                    TLabel(text: "© 2026 HOUSE CONNECT")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func infoRow(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: icon)
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: sub)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .accessibilityElement(children: .combine)
    }

    private func ecosystemRow(index i: Int, provider: any AccessoryProvider, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            TLabel(text: String(format: "%02d", i + 1))
                .frame(width: 28)
            T3IconImage(systemName: providerIcon(provider.id))
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.displayName)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                HStack(spacing: 8) {
                    TDot(size: 5,
                         color: provider.authorizationState == .authorized
                            ? T3.accent
                            : T3.sub)
                    TLabel(text: statusLabel(for: provider.authorizationState))
                }
            }
            Spacer()
            Text("\(provider.accessories.count)")
                .font(T3.inter(16, weight: .medium))
                .foregroundStyle(T3.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(provider.displayName), \(statusLabel(for: provider.authorizationState)), \(provider.accessories.count) accessories")
    }

    @ViewBuilder
    private func linkRow(icon: String, title: String, sub: String,
                         url: String, isLast: Bool = false) -> some View {
        if let link = URL(string: url) {
            Link(destination: link) {
                HStack(spacing: 14) {
                    T3IconImage(systemName: icon)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(T3.ink)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(T3.inter(15, weight: .medium))
                            .foregroundStyle(T3.ink)
                        TLabel(text: sub)
                    }
                    Spacer()
                    T3IconImage(systemName: "arrow.up.right")
                        .frame(width: 14, height: 14)
                        .foregroundStyle(T3.sub)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { if isLast { TRule() } }
            .accessibilityLabel("\(title). \(sub). Opens external link.")
            .accessibilityAddTraits(.isButton)
        }
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "VERSION \(v) · BUILD \(b)"
    }

    private func providerIcon(_ id: ProviderID) -> String {
        switch id {
        case .homeKit: return "house.fill"
        case .smartThings: return "bolt.fill"
        case .sonos: return "hifispeaker.fill"
        case .nest: return "leaf.fill"
        case .homeAssistant: return "server.rack"
        }
    }

    private func statusLabel(for state: ProviderAuthorizationState) -> String {
        switch state {
        case .authorized: return "CONNECTED"
        case .denied: return "ACCESS DENIED"
        case .notDetermined: return "NOT SET UP"
        case .restricted: return "RESTRICTED"
        case .unavailable: return "UNAVAILABLE"
        }
    }
}
