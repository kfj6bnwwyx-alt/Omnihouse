//
//  T3DeviceAutomationsSection.swift
//  house connect
//
//  Shared "Automations" section mounted inside each device-detail
//  view (light, lock, thermostat, accessory fallback). Shows HA
//  automations that reference the current device, with inline
//  trigger + enable toggle so the user doesn't have to jump to
//  Settings → Automations to act on them.
//
//  Rendering rules:
//  · HA-only — Accessory.provider != .homeAssistant hides the section
//  · Empty after enrichment — hides the section (no "no automations"
//    state; it just disappears)
//  · Enrichment still loading — hides the section until configs fetch
//

import SwiftUI

struct T3DeviceAutomationsSection: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @State private var toast: Toast?

    private var haProvider: HomeAssistantProvider? {
        registry.provider(for: .homeAssistant) as? HomeAssistantProvider
    }

    private var relevant: [HAAutomation] {
        haProvider?.automations(for: accessoryID) ?? []
    }

    var body: some View {
        if !relevant.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                TSectionHead(
                    title: "Automations",
                    count: String(format: "%02d", relevant.count)
                )
                ForEach(Array(relevant.enumerated()), id: \.element.id) { i, auto in
                    row(auto, isLast: i == relevant.count - 1)
                }
            }
            .toast($toast)
        }
    }

    private func row(_ auto: HAAutomation, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: auto.isEnabled ? "bolt.fill" : "bolt.slash")
                .frame(width: 16, height: 16)
                .foregroundStyle(T3.ink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(auto.name)
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                if let summary = auto.actionSummary ?? auto.triggerSummary {
                    Text(summary)
                        .font(T3.mono(9))
                        .foregroundStyle(T3.sub)
                        .tracking(1)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Trigger
            Button {
                Task {
                    do {
                        try await haProvider?.triggerAutomation(entityID: auto.entityID)
                        toast = .success("\(auto.name) triggered")
                    } catch {
                        toast = .error("Couldn't trigger \(auto.name)")
                    }
                }
            } label: {
                T3IconImage(systemName: "play.fill")
                    .frame(width: 12, height: 12)
                    .foregroundStyle(T3.accent)
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Enable/disable
            TPill(isOn: Binding(
                get: { auto.isEnabled },
                set: { enabled in
                    Task {
                        do {
                            try await haProvider?.setAutomationEnabled(
                                entityID: auto.entityID,
                                enabled: enabled
                            )
                        } catch {
                            toast = .error("Couldn't \(enabled ? "enable" : "disable") \(auto.name)")
                        }
                    }
                }
            ))
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .opacity(auto.isEnabled ? 1 : 0.5)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}
