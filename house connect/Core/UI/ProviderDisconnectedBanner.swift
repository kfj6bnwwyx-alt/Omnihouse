//
//  ProviderDisconnectedBanner.swift
//  house connect
//
//  Amber warning row shown on the Dashboard and Devices tab when a
//  provider has lost its connection but still has cached devices
//  showing. Converted to T3/Swiss design system — left accent stripe,
//  TRule hairlines, T3 tokens, no rounded cards.
//

import SwiftUI

/// T3-styled alert row for a single disconnected provider.
/// Left orange stripe + provider name + device count + chevron.
struct ProviderDisconnectedBanner: View {
    let providerName: String
    let deviceCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(T3.accent)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    T3IconImage(systemName: "exclamationmark.triangle.fill")
                        .frame(width: 14, height: 14)
                        .foregroundStyle(T3.accent)
                        .accessibilityHidden(true)
                    Text("\(providerName) disconnected")
                        .font(T3.inter(14, weight: .medium))
                        .foregroundStyle(T3.ink)
                }
                Text("\(deviceCount) device\(deviceCount == 1 ? "" : "s") showing as offline")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
            }

            Spacer()

            T3IconImage(systemName: "chevron.right")
                .frame(width: 10, height: 10)
                .foregroundStyle(T3.sub)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(providerName) disconnected. \(deviceCount) device\(deviceCount == 1 ? "" : "s") offline.")
        .accessibilityHint("Tap to go to connection settings")
    }
}

/// Renders banners for every provider that is disconnected but still
/// has cached accessories. Wrap the call site in a NavigationLink to
/// route to Settings → Connections when tapped.
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
