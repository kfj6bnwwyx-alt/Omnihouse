//
//  HAConnectionBanner.swift
//  house connect
//
//  Global "Home Assistant disconnected" strip shown at the top of the
//  root tab container whenever the HA WebSocket drops while the user
//  has HA configured. Appears on every tab, not just Settings.
//
//  State source: `HomeAssistantProvider.isConnected` (observable,
//  toggled by the WebSocket delegate). We only surface the banner
//  when the provider has a configured auth state other than
//  `.notDetermined` — otherwise a user who never set up HA would
//  see a permanent warning, which is wrong.
//
//  Design: full-width 44pt strip, T3.danger desaturated background,
//  cream text, left wifi.slash glyph, right "Retry" button that calls
//  `registry.startAll()`. Tapping the body navigates to Settings →
//  Home Assistant setup via the T3TabNavigator.
//

import SwiftUI

/// Host view that subscribes to the HA provider and renders the strip
/// when disconnected. Mount via `.overlay(alignment: .top)` from
/// `T3RootView`.
struct HAConnectionBanner: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(T3TabNavigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let ha = haProvider, shouldShow(ha) {
                HAConnectionBannerStrip(
                    onRetry: { Task { await registry.startAll() } },
                    onTap: { navigate() }
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .top).combined(with: .opacity)
                )
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.25),
            value: isDisconnected
        )
    }

    private var haProvider: HomeAssistantProvider? {
        registry.providers.first { $0.id == .homeAssistant } as? HomeAssistantProvider
    }

    private var isDisconnected: Bool {
        guard let ha = haProvider else { return false }
        return shouldShow(ha)
    }

    /// Show only when HA has been configured (authorizationState moved
    /// past `.notDetermined`) AND the websocket is down.
    private func shouldShow(_ ha: HomeAssistantProvider) -> Bool {
        guard !ha.isConnected else { return false }
        switch ha.authorizationState {
        case .notDetermined: return false
        default: return true
        }
    }

    private func navigate() {
        // Drop to the provider list so the user can open HA setup.
        navigator.goToSettings(.providers)
    }
}

// MARK: - Pure presentation strip

/// Visual-only strip. Kept separate so previews can drive it without
/// a full ProviderRegistry in the environment.
struct HAConnectionBannerStrip: View {
    let onRetry: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            T3IconImage(systemName: "wifi.slash")
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.white.opacity(0.95))

            Text("Home Assistant disconnected. Some controls may not work.")
                .font(T3.inter(13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.95))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRetry) {
                Text("RETRY")
                    .font(T3.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry Home Assistant connection")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity)
        .background(bannerBackground)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Home Assistant setup")
    }

    /// Desaturated danger tone — keeps the red semantic without
    /// screaming. Sits between T3.danger and T3.ink.
    private var bannerBackground: some View {
        T3.danger
            .opacity(0.92)
            .overlay(Color.black.opacity(0.08))
    }
}

// MARK: - Preview

#Preview("Disconnected") {
    VStack(spacing: 0) {
        HAConnectionBannerStrip(onRetry: {}, onTap: {})
        Spacer()
    }
    .background(T3.page)
}
