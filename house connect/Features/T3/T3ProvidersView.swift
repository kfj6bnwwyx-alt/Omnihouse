//
//  T3ProvidersView.swift
//  house connect
//
//  T3/Swiss providers/connections settings — status rows for each
//  connected ecosystem.
//

import SwiftUI

struct T3ProvidersView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Settings", onBack: { dismiss() })
                    TTitle(
                        title: "Connections.",
                        subtitle: "\(registry.providers.count) providers configured"
                    )

                    ForEach(Array(registry.providers.enumerated()), id: \.element.id) { i, provider in
                        NavigationLink(value: provider.id) {
                            providerRow(index: i, provider: provider,
                                        isLast: i == registry.providers.count - 1)
                        }
                        .buttonStyle(.t3Row)
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func providerRow(index i: Int, provider: any AccessoryProvider, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            TLabel(text: String(format: "%02d", i + 1))
                .frame(width: 28)

            T3IconImage(systemName: providerIcon(provider.id))
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(T3.inter(15, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(T3.ink)

                HStack(spacing: 8) {
                    TDot(size: 5, color: statusColor(provider.authorizationState))
                    TLabel(text: statusText(provider.authorizationState))
                }
            }

            Spacer()

            Text("\(provider.accessories.count)")
                .font(T3.inter(16, weight: .medium))
                .foregroundStyle(T3.ink)
                .monospacedDigit()

            T3IconImage(systemName: "chevron.right")
                .frame(width: 12, height: 12)
                .foregroundStyle(T3.sub)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
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

    private func statusColor(_ state: ProviderAuthorizationState) -> Color {
        switch state {
        case .authorized: return T3.ok
        case .denied: return T3.danger
        case .notDetermined: return T3.sub
        case .restricted, .unavailable: return T3.accent
        }
    }

    private func statusText(_ state: ProviderAuthorizationState) -> String {
        switch state {
        case .authorized: return "Connected"
        case .denied: return "Denied"
        case .notDetermined: return "Not connected"
        case .restricted: return "Restricted"
        case .unavailable(let reason): return reason
        }
    }
}
