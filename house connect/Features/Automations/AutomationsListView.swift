//
//  AutomationsListView.swift
//  house connect
//
//  List of Home Assistant automations with enable/disable toggles
//  and manual trigger buttons. Reached from Settings → Home →
//  Automations, or from a future dedicated Automations tab.
//
//  Each automation shows:
//    - Name (from friendly_name attribute)
//    - Enabled/disabled toggle (calls automation.turn_on/turn_off)
//    - Manual trigger button (calls automation.trigger)
//    - Last triggered timestamp (from last_triggered attribute)
//

import SwiftUI

struct AutomationsListView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var toast: Toast?

    private var haProvider: HomeAssistantProvider? {
        registry.provider(for: .homeAssistant) as? HomeAssistantProvider
    }

    private var automations: [HAAutomation] {
        haProvider?.automations ?? []
    }

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                    header
                        .padding(.top, 8)

                    if automations.isEmpty {
                        emptyState
                    } else {
                        automationsList
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.color.title)
            }
            .accessibilityLabel("Back")

            Text("Automations")
                .font(Theme.font.screenTitle)
                .foregroundStyle(Theme.color.title)

            Spacer()

            if let count = haProvider?.automations.count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.color.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.color.primary.opacity(0.12)))
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 40))
                .foregroundStyle(Theme.color.muted)
            Text("No automations")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.color.title)
            Text("Automations are created in Home Assistant.\nThey'll appear here once configured.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.subtitle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Automations list

    private var automationsList: some View {
        VStack(spacing: 0) {
            ForEach(automations) { automation in
                automationRow(automation)
                if automation.id != automations.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .hcCard(padding: 0)
    }

    private func automationRow(_ automation: HAAutomation) -> some View {
        HStack(spacing: 12) {
            // Icon chip
            IconChip(
                systemName: automation.isEnabled ? "bolt.fill" : "bolt.slash",
                size: 40
            )

            // Name + last triggered
            VStack(alignment: .leading, spacing: 2) {
                Text(automation.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color.title)

                if let lastTriggered = automation.lastTriggered,
                   !lastTriggered.isEmpty,
                   lastTriggered != "none" {
                    Text("Last: \(formatTimestamp(lastTriggered))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.color.subtitle)
                }
            }

            Spacer()

            // Trigger button
            Button {
                trigger(automation)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.color.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trigger \(automation.name)")
            .accessibilityHint("Manually runs this automation once")

            // Enable/disable toggle
            Toggle("", isOn: Binding(
                get: { automation.isEnabled },
                set: { enabled in
                    toggleEnabled(automation, enabled: enabled)
                }
            ))
            .labelsHidden()
            .tint(Theme.color.primary)
            .accessibilityLabel("\(automation.name) enabled")
        }
        .padding(.horizontal, Theme.space.cardPadding)
        .padding(.vertical, 12)
        .opacity(automation.isEnabled ? 1 : 0.6)
    }

    // MARK: - Actions

    private func trigger(_ automation: HAAutomation) {
        Task {
            do {
                try await haProvider?.triggerAutomation(entityID: automation.entityID)
                toast = .success("\(automation.name) triggered")
            } catch {
                toast = .error("Failed: \(error.localizedDescription)")
            }
        }
    }

    private func toggleEnabled(_ automation: HAAutomation, enabled: Bool) {
        Task {
            do {
                try await haProvider?.setAutomationEnabled(
                    entityID: automation.entityID,
                    enabled: enabled
                )
            } catch {
                toast = .error("Failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func formatTimestamp(_ iso: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: iso) else {
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            guard let date = isoFormatter.date(from: iso) else { return iso }
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}
