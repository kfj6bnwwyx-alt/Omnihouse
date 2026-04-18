//
//  T3ProviderDetailView.swift
//  house connect
//
//  T3/Swiss per-provider detail screen — the destination when tapping
//  a row in T3ProvidersView (Settings → Connections → [provider]).
//  Shows connection status, device count, per-provider actions (setup /
//  reauth / token entry), and the device list.
//
//  Replaces the per-provider cards in legacy ProvidersSettingsView.
//

import SwiftUI

struct T3ProviderDetailView: View {
    let providerID: ProviderID

    @Environment(ProviderRegistry.self) private var registry

    private var provider: (any AccessoryProvider)? {
        registry.provider(for: providerID)
    }

    private var accessories: [Accessory] {
        registry.allAccessories
            .filter { $0.id.provider == providerID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var rooms: [Room] {
        provider?.rooms ?? []
    }

    private func roomName(for accessory: Accessory) -> String? {
        guard let roomID = accessory.roomID else { return nil }
        return rooms.first(where: { $0.id == roomID })?.name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(
                    title: providerID.displayLabel + ".",
                    subtitle: statusSubtitle
                )

                statusSection

                if hasConfigAction {
                    configSection
                }

                devicesSection

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }

    // MARK: - Status

    private var statusSubtitle: String {
        "\(accessories.count) accessor\(accessories.count == 1 ? "y" : "ies")  ·  \(rooms.count) room\(rooms.count == 1 ? "" : "s")"
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Status", count: "")

            HStack(alignment: .center, spacing: 14) {
                TDot(size: 8, color: statusColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusText)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    TLabel(text: statusSubLabel)
                }
                Spacer()
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { TRule() }
        }
    }

    private var statusColor: Color {
        guard let provider else { return T3.sub }
        switch provider.authorizationState {
        case .authorized: return T3.ok
        case .denied: return T3.danger
        case .notDetermined: return T3.sub
        case .restricted, .unavailable: return T3.accent
        }
    }

    private var statusText: String {
        guard let provider else { return "Not available" }
        switch provider.authorizationState {
        case .authorized: return "Connected"
        case .denied: return "Denied"
        case .notDetermined: return "Not connected"
        case .restricted: return "Restricted"
        case .unavailable: return "Unavailable"
        }
    }

    private var statusSubLabel: String {
        switch providerID {
        case .homeKit: return "APPLE · LOCAL NETWORK"
        case .smartThings: return "SAMSUNG · TOKEN REQUIRED"
        case .sonos: return "BONJOUR · AUTO-DISCOVERY"
        case .nest: return "GOOGLE SDM · OAUTH"
        case .homeAssistant: return "LOCAL + TAILSCALE"
        }
    }

    // MARK: - Config

    /// Providers that have a user-configurable setup/auth flow.
    private var hasConfigAction: Bool {
        switch providerID {
        case .homeAssistant, .smartThings, .nest: return true
        case .homeKit, .sonos: return false
        }
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Configure", count: "")

            switch providerID {
            case .homeAssistant:
                NavigationLink {
                    HomeAssistantSetupView()
                } label: {
                    configRow(icon: "link", title: "Connection",
                              sub: "URL · token · Tailscale fallback")
                }
                .buttonStyle(.t3Row)

            case .smartThings:
                NavigationLink {
                    SmartThingsTokenEntryView()
                } label: {
                    configRow(icon: "key", title: "Access token",
                              sub: "Personal Access Token from SmartThings")
                }
                .buttonStyle(.t3Row)

            case .nest:
                #if os(iOS)
                NavigationLink {
                    T3NestOAuthView()
                } label: {
                    configRow(icon: "lock", title: "Reauthorize",
                              sub: "Google SDM OAuth flow")
                }
                .buttonStyle(.t3Row)
                #else
                EmptyView()
                #endif

            case .homeKit, .sonos:
                EmptyView()
            }
        }
    }

    private func configRow(icon: String, title: String, sub: String) -> some View {
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

            T3IconImage(systemName: "chevron.right")
                .frame(width: 12, height: 12)
                .foregroundStyle(T3.sub)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Devices

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Devices",
                         count: String(format: "%02d", accessories.count))

            if accessories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No devices reported.")
                        .font(T3.inter(14, weight: .regular))
                        .foregroundStyle(T3.ink)
                    TLabel(text: emptyHint)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 18)
                .overlay(alignment: .top) { TRule() }
                .overlay(alignment: .bottom) { TRule() }
            } else {
                ForEach(Array(accessories.enumerated()), id: \.element.id) { i, accessory in
                    NavigationLink(value: accessory.id) {
                        deviceRow(i: i, accessory: accessory)
                    }
                    .buttonStyle(.t3Row)
                }
            }
        }
    }

    private var emptyHint: String {
        switch providerID {
        case .homeKit: return "PAIR IN APPLE HOME APP"
        case .smartThings: return "ADD TOKEN OR PAIR IN SMARTTHINGS APP"
        case .sonos: return "POWER ON SPEAKERS ON SAME WI-FI"
        case .nest: return "REAUTHORIZE ABOVE"
        case .homeAssistant: return "ADD URL + TOKEN ABOVE"
        }
    }

    private func deviceRow(i: Int, accessory: Accessory) -> some View {
        HStack(spacing: 14) {
            TLabel(text: String(format: "%02d", i + 1))
                .frame(width: 28, alignment: .leading)

            T3IconImage(systemName: iconName(for: accessory.category))
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(accessory.name)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                TLabel(text: roomName(for: accessory)?.uppercased() ?? "UNASSIGNED")
            }

            Spacer()

            TDot(size: 7, color: accessory.isReachable ? T3.ink : T3.sub)

            T3IconImage(systemName: "chevron.right")
                .frame(width: 12, height: 12)
                .foregroundStyle(T3.sub)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { TRule() }
    }

    private func iconName(for category: Accessory.Category) -> String {
        switch category {
        case .light: return "lightbulb"
        case .thermostat: return "thermometer.medium"
        case .lock: return "lock"
        case .speaker: return "hifispeaker"
        case .camera: return "video"
        case .fan: return "fan"
        case .blinds: return "rectangle.on.rectangle"
        case .outlet: return "bolt"
        case .switch: return "power"
        case .sensor: return "target"
        case .television: return "tv"
        case .smokeAlarm: return "exclamationmark.triangle"
        case .other: return "ellipsis"
        }
    }
}
