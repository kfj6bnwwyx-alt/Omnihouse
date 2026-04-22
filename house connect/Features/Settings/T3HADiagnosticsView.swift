//
//  T3HADiagnosticsView.swift
//  house connect
//
//  Home Assistant integration health screen. Read-only — no writes to
//  provider state beyond the explicit action buttons (reconnect, refresh
//  registry). Surfaces the counts, timestamps, and version strings the
//  user needs to verify their Nabu Casa + Sonos + Nest + SmartThings
//  bridging is healthy after initial HA setup.
//
//  Design: Swiss / T3. Stacked sections, generous whitespace, monospaced
//  counts right-aligned. No cards, no gradients, no nested surfaces.
//

import Combine
import SwiftUI
import UIKit

struct T3HADiagnosticsView: View {
    @Environment(ProviderRegistry.self) private var registry

    @State private var snapshot: HomeAssistantProvider.DiagnosticsSnapshot?
    @State private var showUnclassifiedSheet: Bool = false
    @State private var copiedFeedback: Bool = false
    @State private var now: Date = Date()

    // 1s tick drives the "Xs ago" / "Connected for Xm Ys" labels so they
    // stay live without polling the provider.
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var provider: HomeAssistantProvider? {
        registry.provider(for: .homeAssistant) as? HomeAssistantProvider
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Diagnostics.", subtitle: "Home Assistant")
                    .t3ScreenTopPad()

                if let provider {
                    connectionSection(provider)
                    entityRegistrySection()
                    devicesSection(provider)
                    latencySection(provider)
                    actionsSection(provider)
                } else {
                    notConfiguredSection
                }

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onAppear { refreshSnapshot() }
        .onReceive(tick) { now = $0 }
        .sheet(isPresented: $showUnclassifiedSheet) {
            unclassifiedSheet
                .modifier(T3SheetChromeModifier())
        }
    }

    // MARK: - Connection

    @ViewBuilder
    private func connectionSection(_ p: HomeAssistantProvider) -> some View {
        TSectionHead(title: "Connection", count: nil)

        HStack(spacing: 14) {
            TDot(size: 10, color: statusTint(p))
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle(p))
                    .font(T3.inter(16, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: statusSubtitle(p))
            }
            Spacer()
            if let v = p.haVersion {
                Text("v\(v)")
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }

        if let url = p.serverURL {
            diagRow(label: "URL", value: url.absoluteString, monoValue: true)
        }

        if let connectedAt = p.connectedAt, p.isConnected {
            diagRow(label: "Uptime", value: durationString(from: connectedAt, to: now))
        } else if let last = p.lastRefreshed {
            diagRow(label: "Last sync", value: relativeString(from: last, to: now))
        }

        if let err = p.lastError, !p.isConnected {
            diagRow(label: "Error", value: err, emphasize: true)
        }

        TRule()
    }

    // MARK: - Entity registry

    @ViewBuilder
    private func entityRegistrySection() -> some View {
        let snap = snapshot
        TSectionHead(
            title: "Entity Registry",
            count: snap.map { String(format: "%03d", $0.entityCount) } ?? "—"
        )

        if let snap, !snap.entitiesByDomain.isEmpty {
            ForEach(Array(snap.entitiesByDomain.enumerated()), id: \.element.domain) { _, item in
                domainRow(domain: item.domain, count: item.count)
            }
            TRule()
        } else {
            diagRow(label: "No entities cached", value: "—")
        }

        if let snap {
            diagRow(label: "Registry entries", value: String(snap.entityRegistryCount))
            diagRow(label: "Areas", value: String(snap.areaRegistryCount))
            TRule()
        }
    }

    // MARK: - Devices (accessories)

    @ViewBuilder
    private func devicesSection(_ p: HomeAssistantProvider) -> some View {
        let byCat = Dictionary(grouping: p.accessories, by: \.category)
            .map { (label: categoryLabel($0.key), count: $0.value.count, key: $0.key) }
            .sorted { $0.count > $1.count }

        TSectionHead(
            title: "Devices",
            count: String(format: "%03d", p.accessories.count)
        )

        if p.accessories.isEmpty {
            diagRow(label: "No devices", value: "—")
            TRule()
        } else {
            ForEach(Array(byCat.enumerated()), id: \.element.key) { _, item in
                domainRow(domain: item.label, count: item.count)
            }
            TRule()

            if let snap = snapshot, !snap.unclassifiedAccessories.isEmpty {
                Button {
                    showUnclassifiedSheet = true
                } label: {
                    HStack(spacing: 12) {
                        TLabel(text: "View unclassified")
                        Spacer()
                        Text("\(snap.unclassifiedAccessories.count)")
                            .font(T3.inter(15, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .monospacedDigit()
                        T3IconImage(systemName: "chevron.right")
                            .frame(width: 12, height: 12)
                            .foregroundStyle(T3.sub)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, T3.rowVerticalPad)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.t3Row)
                .overlay(alignment: .bottom) { TRule() }
                .accessibilityLabel("View \(snap.unclassifiedAccessories.count) unclassified accessories")
            }
        }
    }

    // MARK: - Latency / events

    @ViewBuilder
    private func latencySection(_ p: HomeAssistantProvider) -> some View {
        TSectionHead(title: "Realtime", count: nil)

        if let last = p.lastStateUpdateAt {
            diagRow(label: "Last state update", value: relativeString(from: last, to: now))
        } else {
            diagRow(label: "Last state update", value: "—")
        }

        // TODO: Track WebSocket ping round-trip times (median of last 10)
        // in HomeAssistantWebSocketClient. Current ping() is fire-and-forget
        // so we have no RTT sample. Not done here to avoid touching the
        // WS client surface in this wave.
        diagRow(label: "WebSocket latency", value: "—")

        if let last = p.lastRefreshed {
            diagRow(label: "Last registry sync", value: relativeString(from: last, to: now))
        }
        TRule()
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionsSection(_ p: HomeAssistantProvider) -> some View {
        TSectionHead(title: "Actions", count: nil)

        Button {
            Task { await p.start() }
        } label: {
            actionRow(icon: "arrow.clockwise", title: "Reconnect",
                      sub: "Re-establish WebSocket connection")
        }
        .buttonStyle(.t3Row)
        .overlay(alignment: .top) { TRule() }

        Button {
            Task { await p.refresh() }
        } label: {
            actionRow(icon: "arrow.clockwise", title: "Refresh Registry",
                      sub: "Re-fetch devices, entities, areas")
        }
        .buttonStyle(.t3Row)
        .overlay(alignment: .top) { TRule() }

        Button {
            copyDiagnostics(p)
        } label: {
            actionRow(
                icon: copiedFeedback ? "checkmark" : "doc.on.doc",
                title: copiedFeedback ? "Copied" : "Copy Diagnostics",
                sub: "JSON summary for bug reports"
            )
        }
        .buttonStyle(.t3Row)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var notConfiguredSection: some View {
        TSectionHead(title: "Connection", count: nil)
        HStack(spacing: 14) {
            TDot(size: 10, color: T3.sub)
            VStack(alignment: .leading, spacing: 3) {
                Text("Not configured")
                    .font(T3.inter(16, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: "SET UP HOME ASSISTANT IN SETTINGS")
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Unclassified sheet

    @ViewBuilder
    private var unclassifiedSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Unclassified.",
                       subtitle: "Devices we couldn't categorize")
                    .t3ScreenTopPad()

                if let list = snapshot?.unclassifiedAccessories {
                    TSectionHead(
                        title: "Entities",
                        count: String(format: "%02d", list.count)
                    )
                    ForEach(list, id: \.entityID) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(T3.inter(15, weight: .medium))
                                .foregroundStyle(T3.ink)
                            Text(item.entityID)
                                .font(T3.mono(11))
                                .foregroundStyle(T3.sub)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) { TRule() }
                    }
                    TRule()
                }
                Spacer(minLength: 60)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func diagRow(label: String, value: String,
                         monoValue: Bool = false,
                         emphasize: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            TLabel(text: label)
            Spacer(minLength: 16)
            Text(value)
                .font(monoValue ? T3.mono(12) : T3.inter(14, weight: .regular))
                .foregroundStyle(emphasize ? T3.danger : T3.ink)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { TRule() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    @ViewBuilder
    private func domainRow(domain: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(domain)
                .font(T3.inter(14, weight: .regular))
                .foregroundStyle(T3.ink)
            Spacer()
            Text(String(format: "%03d", count))
                .font(T3.mono(13))
                .foregroundStyle(T3.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { TRule() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(domain), \(count)")
    }

    @ViewBuilder
    private func actionRow(icon: String, title: String, sub: String) -> some View {
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
            T3IconImage(systemName: "chevron.right")
                .frame(width: 12, height: 12)
                .foregroundStyle(T3.sub)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, T3.rowVerticalPad)
        .contentShape(Rectangle())
    }

    // MARK: - Formatting

    private func statusTint(_ p: HomeAssistantProvider) -> Color {
        if p.isConnected { return T3.ok }
        switch p.authorizationState {
        case .authorized: return T3.ok
        case .notDetermined: return T3.sub
        default: return T3.danger
        }
    }

    private func statusTitle(_ p: HomeAssistantProvider) -> String {
        if p.isConnected { return "Connected" }
        switch p.authorizationState {
        case .authorized: return "Connecting…"
        case .notDetermined: return "Not configured"
        case .denied: return "Authentication failed"
        case .restricted: return "Restricted"
        case .unavailable: return "Unreachable"
        }
    }

    private func statusSubtitle(_ p: HomeAssistantProvider) -> String {
        if p.isConnected { return "WEBSOCKET ACTIVE" }
        if case .unavailable(let reason) = p.authorizationState {
            return reason.uppercased()
        }
        return "DISCONNECTED"
    }

    private func categoryLabel(_ c: Accessory.Category) -> String {
        switch c {
        case .light: return "Lights"
        case .switch: return "Switches"
        case .outlet: return "Outlets"
        case .thermostat: return "Climate"
        case .lock: return "Locks"
        case .sensor: return "Sensors"
        case .camera: return "Cameras"
        case .fan: return "Fans"
        case .blinds: return "Blinds"
        case .speaker: return "Speakers"
        case .television: return "Televisions"
        case .appleTV: return "Apple TVs"
        case .smokeAlarm: return "Smoke alarms"
        case .other: return "Unclassified"
        }
    }

    private func durationString(from start: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private func relativeString(from date: Date, to now: Date) -> String {
        let delta = max(0, Int(now.timeIntervalSince(date)))
        if delta < 60 { return "\(delta)s ago" }
        if delta < 3600 { return "\(delta / 60)m ago" }
        if delta < 86400 { return "\(delta / 3600)h ago" }
        return "\(delta / 86400)d ago"
    }

    // MARK: - Snapshot + actions

    private func refreshSnapshot() {
        guard let provider else { return }
        snapshot = provider.diagnosticsSnapshot()
    }

    private func copyDiagnostics(_ p: HomeAssistantProvider) {
        refreshSnapshot()
        var lines: [String] = []
        lines.append("House Connect · Home Assistant Diagnostics")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")
        lines.append("URL: \(p.serverURL?.absoluteString ?? "—")")
        lines.append("Version: \(p.haVersion ?? "—")")
        lines.append("Connected: \(p.isConnected)")
        lines.append("Auth: \(p.authorizationState)")
        if let c = p.connectedAt {
            lines.append("Connected at: \(ISO8601DateFormatter().string(from: c))")
        }
        if let r = p.lastRefreshed {
            lines.append("Last refresh: \(ISO8601DateFormatter().string(from: r))")
        }
        if let s = snapshot {
            lines.append("")
            lines.append("Entities: \(s.entityCount)")
            lines.append("Registry entries: \(s.entityRegistryCount)")
            lines.append("Areas: \(s.areaRegistryCount)")
            lines.append("")
            lines.append("Entities by domain:")
            for item in s.entitiesByDomain {
                lines.append("  \(item.domain): \(item.count)")
            }
            lines.append("")
            lines.append("Accessories: \(p.accessories.count)")
            if !s.unclassifiedAccessories.isEmpty {
                lines.append("Unclassified:")
                for item in s.unclassifiedAccessories {
                    lines.append("  \(item.entityID) (\(item.name))")
                }
            }
        }
        if let err = p.lastError {
            lines.append("")
            lines.append("Last error: \(err)")
        }

        UIPasteboard.general.string = lines.joined(separator: "\n")
        copiedFeedback = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            copiedFeedback = false
        }
    }
}

#if DEBUG
#Preview("Connected") {
    let registry = ProviderRegistry()
    let provider = HomeAssistantProvider(tokenStore: KeychainTokenStore())
    registry.register(provider)
    return NavigationStack {
        T3HADiagnosticsView()
            .environment(registry)
    }
}
#endif
