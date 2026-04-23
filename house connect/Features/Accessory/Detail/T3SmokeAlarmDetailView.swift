//
//  T3SmokeAlarmDetailView.swift
//  house connect
//
//  T3/Swiss detail screen for smoke/CO alarms. Replaces the generic
//  T3AccessoryDetailView fallback that `.smokeAlarm` previously
//  routed to, so Live Activity simulate + recorded event history
//  have a real home in the UI.
//
//  Infrastructure already in place:
//    - SmokeAlertController runs the 3-step simulate pipeline
//      (warning → critical → auto-end) and writes Live Activity
//      updates. iOS only.
//    - SmokeAlarmEventStore persists recorded events, seeded with
//      demo entries by DemoNestProvider on first launch.
//

import SwiftUI

struct T3SmokeAlarmDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(SmokeAlarmEventStore.self) private var eventStore
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(SmokeAlertController.self) private var alertController
    #endif

    @State private var isSimulating = false

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

    private var events: [SmokeAlarmEvent] {
        eventStore.events(for: accessoryID.nativeID)
    }

    private var batteryPercent: Int? {
        accessory?.batteryLevel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                THeader(
                    backLabel: roomName,
                    rightLabel: heroStatus.label,
                    showDot: heroStatus.isAlert,
                    onBack: { dismiss() }
                )

                TTitle(
                    title: (accessory?.name ?? "Smoke Alarm") + ".",
                    subtitle: "\(providerLabel)  ·  \(roomName.uppercased())"
                )

                // Hero status — one big, scannable word telling the
                // user whether the alarm is happy. Smoke/CO detection
                // state isn't on Accessory yet; today "ALERT" only
                // fires when the device reports unreachable. Once a
                // real Nest SDM stream lands we'll add `SMOKE` /
                // `CO` overrides ahead of unreachable.
                statusHero
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    .padding(.horizontal, T3.screenPadding)
                    .overlay(alignment: .bottom) { TRule() }

                if let pct = batteryPercent {
                    batteryBar(percent: pct)
                }

                // Status — compact reachability + provider summary.
                TSectionHead(title: "Status")
                statusRow(
                    label: "REACHABLE",
                    value: (accessory?.isReachable ?? false) ? "Yes" : "No"
                )
                statusRow(
                    label: "PROVIDER",
                    value: providerLabel,
                    isLast: true
                )

                #if os(iOS)
                // Simulate — kicks the full Live Activity pipeline without
                // requiring a real Nest event. Only available on iOS since
                // ActivityKit isn't on macOS.
                TSectionHead(title: "Simulate")
                simulateButton
                Text("Starts a warning-level Live Activity, escalates to critical after ~5s, auto-ends after ~30s.")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(3)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 10)
                #endif

                // Recent events — persisted history from
                // SmokeAlarmEventStore. Demo provider seeds some on
                // first launch; real Nest stream would append here.
                TSectionHead(
                    title: "Recent events",
                    count: events.isEmpty ? nil : String(format: "%02d", events.count)
                )
                if events.isEmpty {
                    Text("No events recorded yet.")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) { TRule() }
                        .overlay(alignment: .bottom) { TRule() }
                } else {
                    ForEach(Array(events.enumerated()), id: \.element.id) { i, event in
                        eventRow(event, isLast: i == events.count - 1)
                    }
                }

                TSectionHead(title: "Device")
                RemoveDeviceSection(accessoryID: accessoryID)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .modifier(T3SheetChromeModifier())
    }

    // MARK: - Hero status

    /// "SAFE" when the alarm is reachable and battery (if reported)
    /// is above 20%. "CHECK" when the battery is low but the alarm
    /// is otherwise healthy — a gentler warning than "ALERT".
    /// "ALERT" when the device is unreachable. Once Accessory
    /// exposes smoke/CO capability, that signal overrides all
    /// three and flips this to a red "SMOKE" / "CO" hero.
    private var heroStatus: (label: String, isAlert: Bool) {
        guard let accessory else { return ("UNKNOWN", true) }
        if !accessory.isReachable { return ("ALERT", true) }
        if let pct = batteryPercent, pct <= 20 { return ("CHECK", false) }
        return ("SAFE", false)
    }

    private var statusHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(heroStatus.label)
                .font(T3.inter(64, weight: .medium))
                .tracking(-2.5)
                .foregroundStyle(heroStatus.isAlert ? T3.danger : T3.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                TLabel(text: heroSubLabel)
                if let pct = batteryPercent {
                    Text("BATTERY \(pct)%")
                        .font(T3.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(T3.sub)
                }
            }
        }
    }

    private var heroSubLabel: String {
        guard let accessory else { return "—" }
        if !accessory.isReachable { return "UNREACHABLE" }
        if let pct = batteryPercent, pct <= 20 { return "LOW BATTERY" }
        return "ALL CLEAR"
    }

    /// Hairline battery bar under the hero. Orange dot signals
    /// low battery (≤ 20%) without shouting — the number in the
    /// hero caption already does the work.
    private func batteryBar(percent: Int) -> some View {
        let clamped = max(0, min(100, percent))
        let isLow = clamped <= 20
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TLabel(text: "BATTERY")
                Spacer()
                if isLow { TDot(size: 5, color: T3.accent) }
                Text("\(clamped)%")
                    .font(T3.mono(10))
                    .tracking(1.2)
                    .foregroundStyle(isLow ? T3.accent : T3.sub)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(T3.rule)
                        .frame(height: 2)
                    Rectangle()
                        .fill(isLow ? T3.accent : T3.ink)
                        .frame(
                            width: geo.size.width * CGFloat(clamped) / 100,
                            height: 2
                        )
                }
            }
            .frame(height: 2)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Rows

    private func statusRow(label: String, value: String, isLast: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(T3.mono(10))
                .tracking(1.2)
                .foregroundStyle(T3.sub)
            Spacer()
            Text(value)
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.ink)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private func eventRow(_ event: SmokeAlarmEvent, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: event.iconName)
                .frame(width: 16, height: 16)
                .foregroundStyle(eventTint(event))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                if let detail = event.detail, !detail.isEmpty {
                    Text(detail)
                        .font(T3.inter(12, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(event.relativeTime)
                .font(T3.mono(10))
                .tracking(0.8)
                .foregroundStyle(T3.sub)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private func eventTint(_ event: SmokeAlarmEvent) -> Color {
        switch event.iconColor {
        case "red":    return T3.danger
        case "orange": return T3.accent
        case "green":  return T3.ink
        case "blue":   return T3.sub
        default:       return T3.ink
        }
    }

    // MARK: - Simulate

    #if os(iOS)
    private var simulateButton: some View {
        Button {
            guard let accessory, !isSimulating else { return }
            isSimulating = true
            Task {
                await alertController.simulate(
                    using: accessory,
                    roomName: roomName == "—" ? nil : roomName
                )
                isSimulating = false
            }
        } label: {
            HStack(spacing: 10) {
                if isSimulating {
                    ProgressView()
                        .tint(T3.page)
                        .scaleEffect(0.8)
                } else {
                    T3IconImage(systemName: "play.fill")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(T3.page)
                }
                Text(isSimulating ? "SIMULATING ALERT…" : "RUN ALERT SIMULATION")
                    .font(T3.mono(12))
                    .tracking(2)
                    .foregroundStyle(T3.page)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(T3.ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(.t3Row)
        .disabled(isSimulating || accessory == nil)
        .opacity(isSimulating ? 0.65 : 1)
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 4)
    }
    #endif
}
