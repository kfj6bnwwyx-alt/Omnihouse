//
//  T3SettingsTabView.swift
//  house connect
//
//  T3/Swiss Settings tab — grouped rows with section headers.
//

import SwiftUI

struct T3SettingsTabView: View {
    @Environment(ProviderRegistry.self) private var registry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Settings.")

                // Account
                settingsSection(title: "Account", count: "01", rows: [
                    ("person", "Profile", "Name, email, preferences"),
                ])

                // Connections
                settingsSection(title: "Connections", count: "04", rows: [
                    ("wifi", "HomeKit", "6 accessories"),
                    ("bolt", "SmartThings", "4 accessories"),
                    ("hifispeaker", "Sonos", "3 speakers"),
                    ("house", "Home Assistant", "Connected"),
                ])

                // Preferences
                settingsSection(title: "Preferences", count: "03", rows: [
                    ("paintbrush", "Appearance", "Light · Fahrenheit"),
                    ("bell", "Notifications", "All enabled"),
                    ("lock.shield", "Privacy", "Standard"),
                ])

                // Automation
                settingsSection(title: "Automation", count: "02", rows: [
                    ("sparkles", "Scenes", "5 scenes"),
                    ("gearshape.2", "Automations", "3 active"),
                ])

                // System
                settingsSection(title: "System", count: "03", rows: [
                    ("map", "Network", "Topology + diagnostics"),
                    ("externaldrive", "Backup", "Last: Today"),
                    ("arrow.triangle.2.circlepath", "Updates", "Up to date"),
                ])

                // Version footer
                HStack {
                    Spacer()
                    TLabel(text: "House Connect · 1.0.0 · Build 214")
                    Spacer()
                }
                .padding(.vertical, 24)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }

    private func settingsSection(title: String, count: String, rows: [(String, String, String)]) -> some View {
        VStack(spacing: 0) {
            TSectionHead(title: title, count: count)

            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack(spacing: 14) {
                    Image(systemName: row.0)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.1)
                            .font(T3.inter(15, weight: .medium))
                            .foregroundStyle(T3.ink)
                        Text(row.2)
                            .font(.system(size: 11))
                            .foregroundStyle(T3.sub)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(T3.sub)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, T3.rowVerticalPad)
                .overlay(alignment: .top) { TRule() }
                .overlay(alignment: .bottom) {
                    if i == rows.count - 1 { TRule() }
                }
            }
        }
    }
}
