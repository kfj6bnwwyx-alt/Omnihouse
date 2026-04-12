//
//  DeviceOfflineView.swift
//  house connect
//
//  Shown by `DeviceDetailView` when the routed accessory's `isReachable`
//  is false. Pencil node `E7fJS` — "Device Offline" state screen.
//
//  The comp has a large wifi-slash icon, a "Device Offline" headline, the
//  device's name + room as muted subtitle, a three-step Troubleshooting
//  Tips card, and a prominent "Try Reconnecting" button that triggers a
//  provider refresh.
//
//  This is a pure state screen — it reads from the registry and issues
//  a `refresh()` call; it does NOT try to ping the accessory directly.
//  Providers own their own reachability detection.
//

import SwiftUI

struct DeviceOfflineView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var isRetrying = false

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    /// True when this device's provider has lost its connection (token
    /// missing, expired, or denied). Shows provider-specific guidance
    /// instead of generic troubleshooting tips.
    private var isProviderDisconnected: Bool {
        guard let provider = registry.provider(for: accessoryID.provider) else { return false }
        return provider.authorizationState != .authorized
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms.first { $0.id == roomID && $0.provider == accessory.id.provider }?.name
    }

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                DeviceDetailHeader(
                    title: accessory?.name ?? "Device",
                    subtitle: roomName,
                    isOn: nil,
                    onTogglePower: { _ in }
                )
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 8)

                Spacer(minLength: 24)

                VStack(spacing: 20) {
                    // Big icon — changes based on whether this is a
                    // provider-level auth issue or a device-level problem.
                    ZStack {
                        Circle()
                            .fill(isProviderDisconnected
                                  ? Color.orange.opacity(0.12)
                                  : Theme.color.iconChipFill)
                            .frame(width: 120, height: 120)
                        Image(systemName: isProviderDisconnected
                              ? "link.badge.plus"
                              : "wifi.slash")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(isProviderDisconnected
                                             ? .orange
                                             : Theme.color.iconChipGlyph)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text(isProviderDisconnected
                             ? "\(accessoryID.provider.displayLabel) Disconnected"
                             : "Device Offline")
                            .font(Theme.font.screenTitle)
                            .foregroundStyle(Theme.color.title)
                        Text(isProviderDisconnected
                             ? "\(accessory?.name ?? "This device") can't be reached because \(accessoryID.provider.displayLabel) isn't connected."
                             : "\(accessory?.name ?? "This device") isn't responding right now.")
                            .font(Theme.font.cardSubtitle)
                            .foregroundStyle(Theme.color.subtitle)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    // Tips card — provider-specific or generic
                    if isProviderDisconnected {
                        providerDisconnectedCard
                            .padding(.horizontal, Theme.space.screenHorizontal)
                            .padding(.top, 8)
                    } else {
                        troubleshootingCard
                            .padding(.horizontal, Theme.space.screenHorizontal)
                            .padding(.top, 8)
                    }
                }

                Spacer()

                if isProviderDisconnected {
                    NavigationLink(value: SettingsDestination.providers) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                            Text("Go to Connections")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(Theme.color.primary)
                        )
                    }
                    .accessibilityLabel("Go to Connections")
                    .accessibilityHint("Opens provider settings to reconnect \(accessoryID.provider.displayLabel)")
                    .padding(.horizontal, Theme.space.screenHorizontal)
                } else {
                    Button {
                        Task { await retry() }
                    } label: {
                        HStack(spacing: 8) {
                            if isRetrying {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isRetrying ? "Reconnecting…" : "Try Reconnecting")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(Theme.color.primary)
                        )
                    }
                    .disabled(isRetrying)
                    .accessibilityLabel(isRetrying ? "Reconnecting" : "Try Reconnecting")
                    .accessibilityHint("Attempts to reconnect to \(accessory?.name ?? "the device")")
                    .padding(.horizontal, Theme.space.screenHorizontal)
                }

                // Remove button — offline devices are prime candidates for
                // permanent removal (user unplugged for good, replaced device, etc.)
                RemoveDeviceSection(accessoryID: accessoryID)
                    .padding(.horizontal, Theme.space.screenHorizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Provider-disconnected card

    private var providerDisconnectedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to Reconnect")
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)

            if accessoryID.provider == .smartThings {
                tip(number: 1,
                    title: "Get a new access token",
                    body: "Go to account.smartthings.com → Personal Access Tokens and create a new token.")
                tip(number: 2,
                    title: "Open Connections",
                    body: "Tap the button below to go to Settings → Connections.")
                tip(number: 3,
                    title: "Paste & connect",
                    body: "Tap \"Connect with access token\" and paste your new token.")
            } else {
                tip(number: 1,
                    title: "Check \(accessoryID.provider.displayLabel)",
                    body: "Open the \(accessoryID.provider.displayLabel) app and make sure your account is active.")
                tip(number: 2,
                    title: "Reconnect in Settings",
                    body: "Tap the button below to go to Settings → Connections and re-authorize.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }

    // MARK: - Troubleshooting card

    private var troubleshootingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Troubleshooting Tips")
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)

            tip(number: 1,
                title: "Check the power",
                body: "Make sure the device is plugged in and powered on.")
            tip(number: 2,
                title: "Check your Wi-Fi",
                body: "Confirm both your phone and the device are on the same network.")
            tip(number: 3,
                title: "Restart the device",
                body: "Unplug for 10 seconds, then plug back in.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }

    private func tip(number: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.color.iconChipFill)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.color.iconChipGlyph)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.color.subtitle)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title). \(body)")
    }

    // MARK: - Retry

    private func retry() async {
        isRetrying = true
        defer { isRetrying = false }
        // `startAll()` is idempotent — re-kicking the registry asks every
        // provider to re-run its start flow, which is the closest thing
        // to a generic "refresh" on the protocol. Provider-specific
        // refresh buttons live in ProvidersSettingsView.
        await registry.startAll()
    }
}
