//
//  NetworkSettingsView.swift
//  house connect
//
//  Pencil `q5dco` — Network & Hub configuration screen. Currently all
//  static/placeholder values since there is no real hub hardware yet.
//  When hub integration lands, swap the hard-coded strings for live
//  data from the hub's API.
//

import SwiftUI

struct NetworkSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Placeholder state

    @State private var threadEnabled = true
    @State private var zigbeeEnabled = true
    @State private var zwaveEnabled = false
    @State private var wifiEnabled = true
    @State private var autoDiscovery = true
    @State private var networkName = "HomeConnect-5G"

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    hubConfigurationSection
                    protocolTogglesSection
                    autoDiscoverySection
                    networkNameSection
                    resetButton
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.chip,
                                         style: .continuous)
                            .fill(Theme.color.cardFill)
                            .shadow(color: .black.opacity(0.05),
                                    radius: 6, x: 0, y: 2)
                    )
            }
            .accessibilityLabel("Back")

            Text("Network Settings")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.color.title)

            Spacer()
        }
    }

    // MARK: - Hub Configuration

    private var hubConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hub Configuration")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                hubRow(label: "Hub Name", value: "House Connect Hub Pro")
                Divider().foregroundStyle(Theme.color.divider)
                hubRow(label: "Hub Model", value: "HC-Pro 3000")
                Divider().foregroundStyle(Theme.color.divider)
                firmwareRow
            }
            .hcCard()
        }
    }

    private func hubRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.subtitle)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)
        }
        .padding(.vertical, 10)
    }

    private var firmwareRow: some View {
        HStack {
            Text("Firmware Version")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.subtitle)
            Spacer()
            Text("v4.2.1")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)
            Text("Update")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.color.primary))
        }
        .padding(.vertical, 10)
    }

    // MARK: - Protocol Toggles

    private var protocolTogglesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Protocol Toggles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                protocolToggle(name: "Thread", isOn: $threadEnabled)
                Divider().foregroundStyle(Theme.color.divider)
                protocolToggle(name: "Zigbee", isOn: $zigbeeEnabled)
                Divider().foregroundStyle(Theme.color.divider)
                protocolToggle(name: "Z-Wave", isOn: $zwaveEnabled)
                Divider().foregroundStyle(Theme.color.divider)
                protocolToggle(name: "Wi-Fi", isOn: $wifiEnabled)
            }
            .hcCard()
        }
    }

    private func protocolToggle(name: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.color.title)
        }
        .tint(Theme.color.primary)
        .padding(.vertical, 6)
    }

    // MARK: - Auto-Discovery

    private var autoDiscoverySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Auto-Discovery")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $autoDiscovery) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Discovery")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.color.title)
                        Text("Automatically find new devices")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.color.subtitle)
                    }
                }
                .tint(Theme.color.primary)
            }
            .hcCard()
        }
    }

    // MARK: - Network Name

    private var networkNameSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Network Name")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            HStack(spacing: 10) {
                TextField("Network name", text: $networkName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.color.title)
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.color.muted)
            }
            .hcCard()
        }
    }

    // MARK: - Reset

    private var resetButton: some View {
        HStack {
            Spacer()
            Button {
                // Placeholder — no-op until hub hardware.
            } label: {
                Text("Reset Network")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color.danger)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}
