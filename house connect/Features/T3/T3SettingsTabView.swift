//
//  T3SettingsTabView.swift
//  house connect
//
//  T3/Swiss Settings tab — grouped rows with navigation.
//

import SwiftUI

struct T3SettingsTabView: View {
    @Environment(ProviderRegistry.self) private var registry
    @AppStorage("profile.firstName") private var firstName: String = ""

    private var profileSub: String {
        let trimmed = firstName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Set your name" : trimmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Settings.")
                    .t3ScreenTopPad()

                // Account
                TSectionHead(title: "Account", count: "01")
                settingsRow(icon: "person", title: "Profile", sub: profileSub, destination: .profile)

                // Connections
                TSectionHead(title: "Connections", count: String(format: "%02d", registry.providers.count))
                settingsRow(icon: "wifi", title: "Connections", sub: "\(registry.providers.count) providers", destination: .providers)

                // Home
                TSectionHead(title: "Home", count: "05")
                settingsRow(icon: "square.grid.2x2", title: "Rooms", sub: "\(registry.allRooms.count) rooms", destination: .rooms)
                settingsRow(icon: "sparkles", title: "Scenes", sub: "Cross-ecosystem presets", destination: .scenes)
                settingsRow(icon: "gearshape.2", title: "Automations", sub: "Home Assistant automations", destination: .automations)
                settingsRow(icon: "music.note", title: "Audio Zones", sub: "Multi-room audio", destination: .audioZones)
                // Energy — inline destination rather than a
                // SettingsDestination case because the enum + root
                // switch live in Root views (off-limits for this
                // change). Swap to a SettingsDestination case when
                // the routing enum opens up for edits.
                NavigationLink {
                    T3EnergySettingsView()
                } label: {
                    rowContent(icon: "bolt", title: "Energy", sub: "Sensor · rate")
                }
                .buttonStyle(.t3Row)
                // Home Assistant Diagnostics — inline destination for
                // the same reason as Energy above (enum owned by Root).
                NavigationLink {
                    T3HADiagnosticsView()
                } label: {
                    rowContent(icon: "waveform.path.ecg", title: "Home Assistant Diagnostics", sub: "HA health · counts · versions")
                }
                .buttonStyle(.t3Row)

                // Network
                TSectionHead(title: "Network", count: "01")
                settingsRow(icon: "point.3.connected.trianglepath.dotted", title: "Network Topology", sub: "Devices + diagnostics", destination: .networkTopology)

                // Preferences
                TSectionHead(title: "Preferences", count: "02")
                settingsRow(icon: "paintbrush", title: "Appearance", sub: "Theme · Units", destination: .appearance)
                settingsRow(icon: "bell", title: "Notifications", sub: "Alert preferences", destination: .notifications)

                // Support
                TSectionHead(title: "Support", count: "02")
                settingsRow(icon: "questionmark.circle", title: "Help & FAQ", sub: "Common questions", destination: .helpFAQ)
                settingsRow(icon: "info.circle", title: "About", sub: "Version · Credits", destination: .about)

                // Version footer
                HStack {
                    Spacer()
                    TLabel(text: versionFooter)
                    Spacer()
                }
                .padding(.vertical, 24)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }

    private var versionFooter: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "House Connect · \(v) · Build \(b)"
    }

    @ViewBuilder
    private func settingsRow(icon: String, title: String, sub: String, destination: SettingsDestination?) -> some View {
        if let dest = destination {
            NavigationLink(value: dest) {
                rowContent(icon: icon, title: title, sub: sub)
            }
            .buttonStyle(.t3Row)
        } else {
            rowContent(icon: icon, title: title, sub: sub)
        }
    }

    private func rowContent(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: icon)
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                Text(sub)
                    .font(T3.inter(11, weight: .regular))
                    .foregroundStyle(T3.sub)
            }

            Spacer()

            T3IconImage(systemName: "chevron.right")
                .frame(width: 12, height: 12)
                .foregroundStyle(T3.sub)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, T3.rowVerticalPad)
        .overlay(alignment: .top) { TRule() }
    }
}
