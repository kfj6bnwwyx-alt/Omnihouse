//
//  T3AutomationsView.swift
//  house connect
//
//  T3/Swiss automations list — trigger buttons + toggles. Backed by
//  Home Assistant (the only provider exposing automations today).
//
//  Enrichment (WAVE automations-expansion): each row now shows a
//  relative "last triggered" time, a one-line trigger/action summary
//  pulled from the automation's config, and the list is searchable.
//  Enrichment depends on `HomeAssistantProvider.enrichAutomations`
//  having run; rows render without the extras until it lands.
//

import SwiftUI

struct T3AutomationsView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss
    @State private var toast: Toast?
    @State private var search: String = ""

    private var haProvider: HomeAssistantProvider? {
        registry.provider(for: .homeAssistant) as? HomeAssistantProvider
    }

    private var automations: [HAAutomation] {
        haProvider?.automations ?? []
    }

    private var filtered: [HAAutomation] {
        let term = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return automations }
        return automations.filter { auto in
            auto.name.lowercased().contains(term)
                || (auto.triggerSummary?.lowercased().contains(term) ?? false)
                || (auto.actionSummary?.lowercased().contains(term) ?? false)
        }
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Settings", onBack: { dismiss() })
                    TTitle(
                        title: "Automations.",
                        subtitle: automations.isEmpty
                            ? "No automations configured"
                            : "\(automations.count) automations"
                    )

                    if !automations.isEmpty {
                        searchField
                    }

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
                    } else if filtered.isEmpty {
                        VStack(spacing: 8) {
                            TLabel(text: "No matches")
                            Text("No automations match “\(search)”.")
                                .font(T3.inter(13, weight: .regular))
                                .foregroundStyle(T3.sub)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, auto in
                            row(auto, index: i, isLast: i == filtered.count - 1)
                        }
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            T3IconImage(systemName: "magnifyingglass")
                .frame(width: 14, height: 14)
                .foregroundStyle(T3.sub)
            TextField("Search", text: $search)
                .font(T3.inter(14, weight: .regular))
                .foregroundStyle(T3.ink)
                .textFieldStyle(.plain)
                .submitLabel(.search)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    T3IconImage(systemName: "xmark.circle.fill")
                        .frame(width: 14, height: 14)
                        .foregroundStyle(T3.sub)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Row

    private func row(_ auto: HAAutomation, index: Int, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            TLabel(text: String(format: "%02d", index + 1))
                .frame(width: 28)

            T3IconImage(systemName: auto.isEnabled ? "bolt.fill" : "bolt.slash")
                .frame(width: 18, height: 18)
                .foregroundStyle(T3.ink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(auto.name)
                    .font(T3.inter(15, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)

                if let summary = summaryLine(for: auto) {
                    Text(summary)
                        .font(T3.mono(9))
                        .foregroundStyle(T3.sub)
                        .tracking(1)
                        .lineLimit(1)
                }

                if let ago = lastTriggeredLabel(for: auto) {
                    Text(ago)
                        .font(T3.mono(9))
                        .foregroundStyle(T3.sub)
                        .tracking(0.8)
                }
            }

            Spacer()

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
                    .frame(width: 14, height: 14)
                    .foregroundStyle(T3.accent)
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TPill(isOn: Binding(
                get: { auto.isEnabled },
                set: { enabled in
                    Task {
                        do {
                            try await haProvider?.setAutomationEnabled(
                                entityID: auto.entityID, enabled: enabled
                            )
                        } catch {
                            toast = .error("Couldn't \(enabled ? "enable" : "disable") \(auto.name)")
                        }
                    }
                }
            ))
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .opacity(auto.isEnabled ? 1 : 0.5)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    /// Prefer the trigger summary over the action summary when both
    /// exist — triggers are a better mental anchor for what the
    /// automation is ("WHEN sun sets" reads better than "TURN ON
    /// patio.lights"). Fallback: whichever one's available.
    private func summaryLine(for auto: HAAutomation) -> String? {
        switch (auto.triggerSummary, auto.actionSummary) {
        case (let t?, let a?): return "\(t)  ·  \(a)"
        case (let t?, nil): return t
        case (nil, let a?): return a
        case (nil, nil): return nil
        }
    }

    /// Parses HA's ISO-8601 `last_triggered` attribute and renders a
    /// relative string (e.g. "Ran 3 min ago"). Returns nil when the
    /// attribute is missing, "none", or unparseable.
    private func lastTriggeredLabel(for auto: HAAutomation) -> String? {
        guard let raw = auto.lastTriggered, !raw.isEmpty, raw != "none" else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: raw)
            ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return "Ran \(raw.prefix(16))" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return "Ran \(rel.localizedString(for: date, relativeTo: Date()))"
    }
}
