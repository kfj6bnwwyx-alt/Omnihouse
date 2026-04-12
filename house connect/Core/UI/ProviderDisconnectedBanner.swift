//
//  ProviderDisconnectedBanner.swift
//  house connect
//
//  Amber warning card shown on the Dashboard and Devices tab when a
//  provider has lost its connection but still has cached devices
//  showing. Gives the user a clear visual cue that something needs
//  attention without being as alarming as a red error state.
//

import SwiftUI

/// Standalone banner for a single disconnected provider. Renders an
/// amber card with the provider name, device count, and a call to
/// action pointing to Settings → Connections.
struct ProviderDisconnectedBanner: View {
    let providerName: String
    let deviceCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(providerName) disconnected")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Text("\(deviceCount) device\(deviceCount == 1 ? "" : "s") showing as offline")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
        }
        .padding(Theme.space.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

/// Helper view that checks all providers and renders banners for any
/// that are disconnected but still have cached accessories. Wrap in a
/// `NavigationLink` at the call site so tapping routes to Connections.
struct DisconnectedProviderBanners: View {
    @Environment(ProviderRegistry.self) private var registry

    var body: some View {
        ForEach(disconnectedProviders, id: \.id) { provider in
            NavigationLink(value: SettingsDestination.providers) {
                ProviderDisconnectedBanner(
                    providerName: provider.displayName,
                    deviceCount: provider.accessories.count
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var disconnectedProviders: [any AccessoryProvider] {
        registry.providers.filter { provider in
            provider.authorizationState != .authorized
            && !provider.accessories.isEmpty
        }
    }
}
