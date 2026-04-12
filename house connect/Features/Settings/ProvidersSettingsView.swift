//
//  ProvidersSettingsView.swift
//  house connect
//
//  Per-provider connection management. This used to be the top-level
//  SettingsView (Phase 2a/3a); once we adopted the Pencil design it
//  moved here so the new top-level Settings screen can match the mock.
//  Every capability from the old screen is preserved: SmartThings token
//  entry, disconnect, refresh, Sonos speaker count, HomeKit status badge,
//  local-network permission link.
//
//  Reached from: Settings → HOME → Connections.
//

import SwiftUI
import UIKit  // for UIApplication.openSettingsURLString

struct ProvidersSettingsView: View {
    @Environment(ProviderRegistry.self) private var registry

    @State private var showingSmartThingsTokenEntry = false
    @State private var confirmDisconnect = false
    @State private var showingNestOAuth = false
    @State private var confirmNestDisconnect = false

    /// Mirror of the same `@AppStorage` key read by `AllDevicesView`.
    /// When a device is published by more than one ecosystem (e.g.
    /// a bulb paired through both HomeKit AND SmartThings), the
    /// Devices tab de-dupes it into a single tile and has to pick
    /// ONE provider to route tap-through to. Default is HomeKit
    /// because it's local-network (lowest latency); power users
    /// who lean on SmartThings automations can flip this here.
    ///
    /// Stored as a String raw value — same minimal pattern as
    /// viewMode, avoids a custom Codable for one setting.
    @AppStorage("devices.preferredProvider") private var preferredProviderRaw: String = ProviderID.homeKit.rawValue

    private var smartThingsProvider: SmartThingsProvider? {
        registry.provider(for: .smartThings) as? SmartThingsProvider
    }

    private var sonosProvider: SonosProvider? {
        registry.provider(for: .sonos) as? SonosProvider
    }

    private var nestProvider: NestProvider? {
        registry.provider(for: .nest) as? NestProvider
    }

    var body: some View {
        Form {
            preferredNetworkSection
            smartThingsSection
            nestSection
            sonosSection
            homeKitSection
        }
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSmartThingsTokenEntry) {
            SmartThingsTokenEntryView()
        }
        .sheet(isPresented: $showingNestOAuth) {
            NestOAuthView()
        }
    }

    // MARK: - Preferred Network

    /// Single-line picker that controls which ecosystem "wins" for
    /// dual-homed devices in the Devices tab's merged view. This is
    /// the user-configurable half of the "never ask the user to
    /// resolve ambiguity" promise — we still auto-route on tap, but
    /// the user gets to pick which provider auto-route means. The
    /// Picker is bound to the SAME `@AppStorage` key the Devices
    /// tab reads, so a change here updates the tiles in place the
    /// next time the tab renders (no restart, no manual refresh).
    ///
    /// Only providers with a currently-registered instance are
    /// offered so the picker can't select Nest on a build where the
    /// demo provider isn't registered, etc.
    private var preferredNetworkSection: some View {
        Section {
            Picker("Preferred network", selection: preferredProviderBinding) {
                ForEach(registry.providers, id: \.id) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
        } header: {
            Text("Devices view")
        } footer: {
            Text("When a device is published by more than one network (e.g. a bulb paired through both HomeKit and SmartThings), the Devices tab shows a single tile. Tapping it routes to this network by default. HomeKit is fastest because it runs on your Wi-Fi without going through the cloud.")
        }
    }

    /// Typed binding wrapper so the Picker can round-trip
    /// `ProviderID` through the raw-String `@AppStorage` key.
    /// Falls through to HomeKit on any garbage rawValue so a bad
    /// write can't wedge the setting.
    private var preferredProviderBinding: Binding<ProviderID> {
        Binding(
            get: { ProviderID(rawValue: preferredProviderRaw) ?? .homeKit },
            set: { preferredProviderRaw = $0.rawValue }
        )
    }

    // MARK: - SmartThings

    @ViewBuilder
    private var smartThingsSection: some View {
        Section {
            if let provider = smartThingsProvider {
                HStack {
                    Label("Samsung SmartThings", systemImage: "house.circle")
                    Spacer()
                    statusBadge(for: provider.authorizationState)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Samsung SmartThings, \(statusLabel(for: provider.authorizationState))")

                if provider.authorizationState == .authorized {
                    LabeledContent("Locations", value: "\(provider.homes.count)")

                    // Tappable device count — pushes a per-provider device
                    // list so the user can drill into any specific accessory
                    // from here without leaving Settings.
                    NavigationLink {
                        ProviderDevicesListView(providerID: .smartThings)
                            .environment(registry)
                    } label: {
                        LabeledContent("Devices", value: "\(provider.accessories.count)")
                    }

                    if let ts = provider.lastRefreshed {
                        LabeledContent("Last refreshed", value: ts.formatted(.relative(presentation: .named)))
                            .accessibilityLabel("Last refreshed \(ts.formatted(.relative(presentation: .named)))")
                    }

                    Button {
                        Task { await provider.refresh() }
                    } label: {
                        if provider.isRefreshing {
                            HStack { ProgressView(); Text("Refreshing…") }
                        } else {
                            Label("Refresh now", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(provider.isRefreshing)
                    .accessibilityLabel("Refresh SmartThings")
                    .accessibilityHint("Fetches the latest devices and locations from SmartThings")

                    Button(role: .destructive) {
                        confirmDisconnect = true
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                    .accessibilityLabel("Disconnect SmartThings")
                    .accessibilityHint("Removes access token and clears all SmartThings devices")
                } else {
                    Button {
                        showingSmartThingsTokenEntry = true
                    } label: {
                        Label("Connect with access token", systemImage: "key.fill")
                    }
                    .accessibilityHint("Opens a sheet to enter your SmartThings personal access token")
                }

                if let error = provider.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Text("SmartThings provider not registered.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("SmartThings")
        } footer: {
            Text("Create a Personal Access Token at account.smartthings.com → Personal Access Tokens. Grant it the Devices, Locations, and Rooms scopes.")
        }
        .confirmationDialog(
            "Disconnect SmartThings?",
            isPresented: $confirmDisconnect,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                Task { await disconnectSmartThings() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your access token will be removed and all SmartThings devices will be cleared from the app. Reconnect anytime with a new token.")
        }
    }

    // MARK: - Nest

    @ViewBuilder
    private var nestSection: some View {
        if let provider = nestProvider {
            Section("Google Nest") {
                HStack {
                    Label("Google Nest", systemImage: "leaf.fill")
                    Spacer()
                    statusBadge(for: provider.authorizationState)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Google Nest, \(statusLabel(for: provider.authorizationState))")

                if provider.authorizationState == .authorized {
                    NavigationLink {
                        ProviderDevicesListView(providerID: .nest)
                            .environment(registry)
                    } label: {
                        LabeledContent("Devices", value: "\(provider.accessories.count)")
                    }

                    if let ts = provider.lastRefreshed {
                        LabeledContent("Last refreshed", value: ts.formatted(.relative(presentation: .named)))
                    }

                    Button("Refresh") {
                        Task { await provider.refresh() }
                    }

                    Button("Disconnect", role: .destructive) {
                        confirmNestDisconnect = true
                    }
                    .confirmationDialog(
                        "Disconnect Google Nest?",
                        isPresented: $confirmNestDisconnect,
                        titleVisibility: .visible
                    ) {
                        Button("Disconnect", role: .destructive) {
                            provider.disconnect()
                        }
                    } message: {
                        Text("Your Nest devices will be removed. You can reconnect at any time.")
                    }
                } else {
                    Button("Connect with Google") {
                        showingNestOAuth = true
                    }
                }

                if let error = provider.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .accessibilityLabel("Error: \(error)")
                }
            }
        }
        // If nestProvider is nil, no Nest section is shown (DemoNestProvider
        // doesn't cast to NestProvider, so this is only visible when real
        // credentials are configured).
    }

    // MARK: - Sonos

    @ViewBuilder
    private var sonosSection: some View {
        Section {
            if let sonos = sonosProvider {
                HStack {
                    Label("Sonos (local)", systemImage: "hifispeaker.fill")
                    Spacer()
                    statusBadge(for: sonos.authorizationState)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Sonos, \(statusLabel(for: sonos.authorizationState))")

                // Tappable speaker count — same drill-down pattern as
                // SmartThings above, so the Settings screen isn't a
                // dead end when you want to open a specific player.
                NavigationLink {
                    ProviderDevicesListView(providerID: .sonos)
                        .environment(registry)
                } label: {
                    LabeledContent("Speakers", value: "\(sonos.accessories.count)")
                }

                if sonos.accessories.isEmpty && sonos.lastError == nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No speakers found yet.")
                            .font(.callout)
                        Text("Make sure your iPhone is on the same Wi-Fi as the speakers, then tap Refresh. If this is your first run, grant Local Network permission when iOS asks.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let ts = sonos.lastRefreshed {
                    LabeledContent("Last refreshed", value: ts.formatted(.relative(presentation: .named)))
                        .accessibilityLabel("Last refreshed \(ts.formatted(.relative(presentation: .named)))")
                }

                Button {
                    Task { await sonos.refresh() }
                } label: {
                    if sonos.isRefreshing {
                        HStack { ProgressView(); Text("Refreshing…") }
                    } else {
                        Label("Refresh now", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(sonos.isRefreshing)
                .accessibilityLabel("Refresh Sonos")
                .accessibilityHint("Scans your local network for Sonos speakers")

                if let error = sonos.lastError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                        Link("Open iOS Settings",
                             destination: URL(string: UIApplication.openSettingsURLString)!)
                            .font(.caption)
                    }
                }
            } else {
                Text("Sonos provider not registered.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Sonos")
        } footer: {
            Text("Discovers Sonos speakers on your Wi-Fi via Bonjour. Requires Local Network permission — grant it in iOS Settings → Privacy & Security → Local Network. Older S1 speakers that don't advertise `_sonos._tcp` won't appear here.")
        }
    }

    // MARK: - HomeKit

    private var homeKitSection: some View {
        Section {
            if let hk = registry.provider(for: .homeKit) {
                HStack {
                    Label(hk.displayName, systemImage: "house.fill")
                    Spacer()
                    statusBadge(for: hk.authorizationState)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(hk.displayName), \(statusLabel(for: hk.authorizationState))")
                LabeledContent("Homes", value: "\(hk.homes.count)")

                // Same drill-down as the other providers above so the
                // Connections screen is a real entry point, not a
                // count-only read-out.
                NavigationLink {
                    ProviderDevicesListView(providerID: .homeKit)
                        .environment(registry)
                } label: {
                    LabeledContent("Accessories", value: "\(hk.accessories.count)")
                }
            } else {
                Text("HomeKit provider not registered.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Apple Home")
        } footer: {
            Text("HomeKit access is granted system-wide in iOS Settings → Privacy & Security → Home.")
        }
    }

    // MARK: - Helpers

    private func statusLabel(for state: ProviderAuthorizationState) -> String {
        switch state {
        case .authorized: return "Connected"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not connected"
        case .unavailable(let reason): return "Unavailable, \(reason)"
        }
    }

    private func statusBadge(for state: ProviderAuthorizationState) -> some View {
        let (label, color): (String, Color) = switch state {
        case .authorized: ("Connected", .green)
        case .denied: ("Denied", .red)
        case .restricted: ("Restricted", .orange)
        case .notDetermined: ("Not connected", .secondary)
        case .unavailable(let reason): ("Unavailable — \(reason)", .gray)
        }
        return Text(label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    private func disconnectSmartThings() async {
        guard let provider = smartThingsProvider else { return }
        let tokenStore = KeychainTokenStore()
        try? tokenStore.delete(.smartThingsPAT)
        // Use disconnect() instead of refresh() so the disk cache is
        // cleared and devices truly vanish (intentional removal).
        provider.disconnect()
    }
}
