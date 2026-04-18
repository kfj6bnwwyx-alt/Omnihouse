//
//  T3AutomationsView.swift
//  house connect
//
//  T3/Swiss automations list — trigger buttons + toggles.
//

import SwiftUI

struct T3AutomationsView: View {
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
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Settings", onBack: { dismiss() })
                    TTitle(
                        title: "Automations.",
                        subtitle: automations.isEmpty ? "No automations configured" : "\(automations.count) automations"
                    )

                    if automations.isEmpty {
                        VStack(spacing: 12) {
                            TLabel(text: "No automations")
                            Text("Create automations in Home Assistant.\nThey'll appear here once configured.")
                                .font(T3.inter(13, weight: .regular))
                                .foregroundStyle(T3.sub)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(Array(automations.enumerated()), id: \.element.id) { i, auto_ in
                            HStack(spacing: 14) {
                                TLabel(text: String(format: "%02d", i + 1))
                                    .frame(width: 28)

                                T3IconImage(systemName: auto_.isEnabled ? "bolt.fill" : "bolt.slash")
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(T3.ink)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(auto_.name)
                                        .font(T3.inter(15, weight: .medium))
                                        .tracking(-0.2)
                                        .foregroundStyle(T3.ink)

                                    if let last = auto_.lastTriggered, !last.isEmpty, last != "none" {
                                        TLabel(text: "Last: \(last.prefix(16))")
                                    }
                                }

                                Spacer()

                                // Trigger button
                                Button {
                                    Task {
                                        try? await haProvider?.triggerAutomation(entityID: auto_.entityID)
                                        toast = .success("\(auto_.name) triggered")
                                    }
                                } label: {
                                    T3IconImage(systemName: "play.fill")
                                        .frame(width: 14, height: 14)
                                        .foregroundStyle(T3.accent)
                                }
                                .buttonStyle(.plain)

                                // Enable toggle
                                TPill(isOn: Binding(
                                    get: { auto_.isEnabled },
                                    set: { enabled in
                                        Task {
                                            try? await haProvider?.setAutomationEnabled(
                                                entityID: auto_.entityID, enabled: enabled
                                            )
                                        }
                                    }
                                ))
                            }
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 14)
                            .opacity(auto_.isEnabled ? 1 : 0.5)
                            .overlay(alignment: .top) { TRule() }
                            .overlay(alignment: .bottom) {
                                if i == automations.count - 1 { TRule() }
                            }
                        }
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }
}
