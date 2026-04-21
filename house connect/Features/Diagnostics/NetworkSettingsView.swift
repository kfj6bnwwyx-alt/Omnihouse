//
//  NetworkSettingsView.swift
//  house connect
//
//  Pencil `q5dco` — Network & Hub configuration screen. All values are
//  placeholder/static — no real hub hardware yet. Converted to T3/Swiss
//  design system: TRule hairlines, T3 tokens, TPill toggles, no rounded
//  cards.
//

import SwiftUI

struct NetworkSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Placeholder state

    @State private var threadEnabled = true
    @State private var zigbeeEnabled = true
    @State private var zwaveEnabled  = false
    @State private var wifiEnabled   = true
    @State private var autoDiscovery = true
    @State private var networkName   = "HomeConnect-5G"

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Device Network", onBack: { dismiss() })

                    TTitle(title: "Network settings.", subtitle: nil)

                    // Hub configuration
                    TSectionHead(title: "Hub configuration")
                    configRow(label: "Hub Name",  value: "House Connect Hub Pro")
                    configRow(label: "Hub Model", value: "HC-Pro 3000")
                    firmwareRow

                    // Protocol toggles
                    TSectionHead(title: "Protocols", count: "04")
                    protocolToggleRow(name: "Thread",  isOn: $threadEnabled)
                    protocolToggleRow(name: "Zigbee",  isOn: $zigbeeEnabled)
                    protocolToggleRow(name: "Z-Wave",  isOn: $zwaveEnabled)
                    protocolToggleRow(name: "Wi-Fi",   isOn: $wifiEnabled, isLast: true)

                    // Auto-discovery
                    TSectionHead(title: "Discovery")
                    autoDiscoveryRow

                    // Network name
                    TSectionHead(title: "Network name")
                    networkNameRow

                    // Reset
                    Button {
                        // Placeholder — no-op until hub hardware.
                    } label: {
                        HStack {
                            Text("Reset network")
                                .font(T3.inter(14, weight: .medium))
                                .foregroundStyle(T3.danger)
                            Spacer()
                            T3IconImage(systemName: "exclamationmark.triangle")
                                .frame(width: 14, height: 14)
                                .foregroundStyle(T3.danger)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) { TRule() }
                        .overlay(alignment: .bottom) { TRule() }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 24)
                    .accessibilityLabel("Reset network")
                    .accessibilityHint("Resets all network settings to factory defaults")

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hub config rows

    private func configRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            TLabel(text: label.uppercased())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(T3.mono(12))
                .foregroundStyle(T3.ink)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { TRule() }
    }

    private var firmwareRow: some View {
        HStack(alignment: .firstTextBaseline) {
            TLabel(text: "Firmware".uppercased())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("v4.2.1")
                .font(T3.mono(12))
                .foregroundStyle(T3.ink)
            Button {} label: {
                Text("UPDATE")
                    .font(T3.mono(9))
                    .tracking(1.2)
                    .foregroundStyle(T3.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(Rectangle().stroke(T3.accent, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .accessibilityLabel("Update firmware")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Protocol toggle rows

    private func protocolToggleRow(
        name: String,
        isOn: Binding<Bool>,
        isLast: Bool = false
    ) -> some View {
        HStack {
            Text(name)
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.ink)
            Spacer()
            TPill(isOn: isOn)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) \(isOn.wrappedValue ? "enabled" : "disabled")")
        .accessibilityHint("Toggle to \(isOn.wrappedValue ? "disable" : "enable")")
    }

    // MARK: - Auto-discovery row

    private var autoDiscoveryRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-Discovery")
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                Text("Automatically find new devices on your network")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineLimit(2)
            }
            Spacer()
            TPill(isOn: $autoDiscovery)
                .padding(.top, 2)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Auto-Discovery \(autoDiscovery ? "enabled" : "disabled")")
        .accessibilityHint("Toggle to \(autoDiscovery ? "disable" : "enable") automatic device discovery")
    }

    // MARK: - Network name row

    private var networkNameRow: some View {
        HStack(spacing: 10) {
            TextField("Network name", text: $networkName)
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.ink)
            T3IconImage(systemName: "pencil")
                .frame(width: 12, height: 12)
                .foregroundStyle(T3.sub)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }
}
