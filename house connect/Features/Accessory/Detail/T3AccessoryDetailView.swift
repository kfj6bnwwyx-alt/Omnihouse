//
//  T3AccessoryDetailView.swift
//  house connect
//
//  Generic T3/Swiss device detail — fallback for device categories
//  without a bespoke screen (sensor / switch / outlet / fan / blinds /
//  other). Renders the full capability set with T3 primitives: hairline
//  rows, mono captions, Inter Tight, no rounded cards, orange dot for
//  on-state.
//

import SwiftUI

struct T3AccessoryDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    @State private var lastErrorMessage: String?

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String {
        guard let accessory, let roomID = accessory.roomID else { return "—" }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? "—"
    }

    private var providerLabel: String {
        accessoryID.provider.displayLabel.uppercased()
    }

    private var hasPower: Bool {
        accessory?.capabilities.contains(where: { $0.kind == .power }) ?? false
    }

    private var isOn: Bool {
        accessory?.isOn ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(
                    title: (accessory?.name ?? "Device") + ".",
                    subtitle: "\(providerLabel)  ·  \(roomName.uppercased())"
                )
                .t3ScreenTopPad()

                TSectionHead(title: "State")
                stateBlock

                if !capabilitiesList.isEmpty {
                    TSectionHead(
                        title: "Capabilities",
                        count: String(format: "%02d", capabilitiesList.count)
                    )
                    ForEach(Array(capabilitiesList.enumerated()), id: \.offset) { i, item in
                        capabilityRow(
                            label: item.label,
                            value: item.value,
                            isLast: i == capabilitiesList.count - 1
                        )
                    }
                }

                TSectionHead(title: "Identifiers")
                identifierRow(label: "NATIVE ID", value: accessory?.id.nativeID ?? "—")
                identifierRow(
                    label: "CATEGORY",
                    value: (accessory?.category.displayLabel ?? "Unknown").uppercased()
                )
                identifierRow(label: "PROVIDER", value: providerLabel, isLast: true)

                if let lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(T3.inter(12, weight: .regular))
                        .foregroundStyle(T3.accent)
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.top, 12)
                        .accessibilityLabel("Command error: \(lastErrorMessage)")
                }

                T3DeviceAutomationsSection(accessoryID: accessoryID)

                TSectionHead(title: "Device")
                RemoveDeviceSection(accessoryID: accessoryID)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        // Applies T3 cream panel background when this view is presented
        // as a sheet (iOS 16.4+). No-op when pushed onto a nav stack.
        .modifier(T3SheetChromeModifier())
    }

    // MARK: - State

    private var stateBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            TDot(size: 8, color: isOn ? T3.accent : T3.sub)
            VStack(alignment: .leading, spacing: 3) {
                Text(isOn ? "On" : "Off")
                    .font(T3.inter(22, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: (accessory?.isReachable ?? false) ? "REACHABLE" : "UNREACHABLE")
            }
            Spacer()

            if hasPower {
                Button {
                    let current = isOn
                    Task {
                        do {
                            try await registry.execute(.setPower(!current), on: accessoryID)
                            await MainActor.run { lastErrorMessage = nil }
                        } catch {
                            await MainActor.run {
                                lastErrorMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    Text(isOn ? "TURN OFF" : "TURN ON")
                        .font(T3.mono(12))
                        .tracking(2)
                        .foregroundStyle(T3.page)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(T3.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOn ? "Turn off" : "Turn on")
                .accessibilityHint("Toggles power for \(accessory?.name ?? "this device")")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 16)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Capabilities

    /// Capability rows as (label, value?) pairs. Power is already shown
    /// in the State block so we skip it here to avoid redundancy.
    private var capabilitiesList: [(label: String, value: String?)] {
        guard let accessory else { return [] }
        return accessory.capabilities
            .filter { $0.kind != .power }
            .map { ($0.displayLabel, $0.valueLabel) }
    }

    private func capabilityRow(label: String, value: String?, isLast: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            TLabel(text: label.uppercased())
            Spacer()
            if let value {
                Text(value)
                    .font(T3.mono(12))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("—")
                    .font(T3.mono(12))
                    .foregroundStyle(T3.sub)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value ?? "unknown")")
    }

    // MARK: - Identifiers

    private func identifierRow(label: String, value: String, isLast: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            TLabel(text: label)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(T3.mono(11))
                .foregroundStyle(T3.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}
