//
//  T3EnergySettingsView.swift
//  house connect
//
//  Settings → Home → Energy. Lets the user pick which Home Assistant
//  sensor drives the Energy dashboard (replacing the long-hardcoded
//  `sensor.energy_home_total` default) and configure the $/kWh rate
//  used for cost estimates.
//
//  @AppStorage keys:
//    - energy.entityID   — HA entity_id of the selected kWh total sensor.
//                          Empty/missing → EnergyService falls back to
//                          HomeAssistantProvider.defaultEnergyStatisticID.
//    - energy.ratePerKwh — user rate in USD. 0/missing → EnergyService
//                          uses EnergyService.defaultRateUSDPerKwh (0.15).
//
//  The picker pulls candidates from the HA state cache via
//  `HomeAssistantProvider.fetchEnergySensorCandidates()`, filtering for
//  `sensor.*` entities that look like energy totals (device_class =
//  energy OR state_class = total/total_increasing with a kWh-ish unit).
//

import SwiftUI

struct T3EnergySettingsView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(EnergyService.self) private var energy

    @AppStorage(EnergyService.entityIDDefaultsKey)
    private var entityID: String = HomeAssistantProvider.defaultEnergyStatisticID

    @AppStorage(EnergyService.ratePerKwhDefaultsKey)
    private var ratePerKwh: Double = EnergyService.defaultRateUSDPerKwh

    @State private var rateText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Energy.", subtitle: "Sensor · rate · refresh")
                    .t3ScreenTopPad()

                // Sensor selection
                TSectionHead(title: "Energy Sensor", count: nil)
                NavigationLink {
                    T3EnergySensorPickerView(selection: $entityID) {
                        Task { await energy.refresh() }
                    }
                } label: {
                    sensorRow
                }
                .buttonStyle(.plain)

                // Rate
                TSectionHead(title: "Rate", count: nil)
                rateRow

                // Force refresh
                TSectionHead(title: "Data", count: nil)
                Button {
                    Task { await energy.refresh() }
                } label: {
                    actionRow(title: "Force Refresh",
                              sub: "RE-FETCH STATISTICS FROM HOME ASSISTANT",
                              icon: "arrow.clockwise",
                              isLast: true)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onAppear {
            // Seed the rate text field from persisted value, formatted
            // with up to 4 digits after the decimal so rates like
            // $0.1234 round-trip cleanly.
            rateText = String(format: "%.4g", ratePerKwh)
        }
    }

    // MARK: - Rows

    private var sensorRow: some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: "bolt")
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("Sensor")
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: entityID.isEmpty
                       ? HomeAssistantProvider.defaultEnergyStatisticID.uppercased()
                       : entityID.uppercased())
            }
            Spacer()
            T3IconImage(systemName: "chevron.right")
                .frame(width: 12, height: 12)
                .foregroundStyle(T3.sub)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    private var rateRow: some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: "dollarsign.circle")
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("USD per kWh")
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: "USED FOR MONTHLY COST ESTIMATE")
            }
            Spacer()
            HStack(spacing: 2) {
                Text("$")
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.sub)
                TextField("0.15", text: $rateText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .frame(width: 72)
                    .onSubmit(commitRate)
                    .onChange(of: rateText) { _, _ in commitRate() }
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    private func actionRow(title: String, sub: String, icon: String, isLast: Bool) -> some View {
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
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    /// Parse the rate-text field, clamp to a sane range, and persist.
    /// Called on both submit and change so typing feels live without
    /// nuking the field when the user is mid-edit (we only commit when
    /// the value actually parses cleanly).
    private func commitRate() {
        let trimmed = rateText.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value > 0, value < 10 else { return }
        ratePerKwh = value
    }
}

// MARK: - Picker

private struct T3EnergySensorPickerView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: String
    let onSelect: () -> Void

    @State private var candidates: [HomeAssistantProvider.EnergySensorCandidate] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Pick sensor.", subtitle: "HOME ASSISTANT ENERGY CANDIDATES")
                    .t3ScreenTopPad()

                if isLoading {
                    loadingRow
                } else if candidates.isEmpty {
                    emptyState
                } else {
                    TSectionHead(title: "Candidates",
                                 count: String(format: "%02d", candidates.count))
                    ForEach(Array(candidates.enumerated()), id: \.element.entityID) { index, cand in
                        Button {
                            selection = cand.entityID
                            onSelect()
                            dismiss()
                        } label: {
                            candidateRow(cand, isLast: index == candidates.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let ha = registry.provider(for: .homeAssistant) as? HomeAssistantProvider else {
            candidates = []
            return
        }
        candidates = await ha.fetchEnergySensorCandidates()
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 32)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No energy sensors found.")
                .font(T3.inter(15, weight: .medium))
                .foregroundStyle(T3.ink)
            Text("Configure Home Assistant's Energy dashboard first, then return here.")
                .font(T3.inter(13, weight: .regular))
                .foregroundStyle(T3.sub)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 20)
    }

    private func candidateRow(_ cand: HomeAssistantProvider.EnergySensorCandidate, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(T3.ink, lineWidth: 1)
                    .frame(width: 18, height: 18)
                if selection == cand.entityID {
                    Circle()
                        .fill(T3.accent)
                        .frame(width: 9, height: 9)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(cand.friendlyName)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: "\(cand.entityID.uppercased())\(cand.unit.map { " · \($0.uppercased())" } ?? "")")
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityLabel("\(cand.friendlyName). \(cand.entityID)")
        .accessibilityAddTraits(selection == cand.entityID ? [.isButton, .isSelected] : .isButton)
    }
}
