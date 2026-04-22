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
                TTitle(
                    title: (accessory?.name ?? "Smoke Alarm") + ".",
                    subtitle: "\(providerLabel)  ·  \(roomName.uppercased())"
                )
                .t3ScreenTopPad()

                // Status — reachable + battery summary. Smoke/CO detection
                // state isn't exposed on Accessory yet; once the Nest SDM
                // stream is wired we can surface it here alongside battery.
                TSectionHead(title: "Status")
                statusRow(
                    label: "REACHABLE",
                    value: (accessory?.isReachable ?? false) ? "Yes" : "No"
                )
                if let pct = batteryPercent {
                    statusRow(label: "BATTERY", value: "\(pct)%")
                }
                statusRow(
                    label: "PROVIDER",
                    value: providerLabel,
                    isLast: batteryPercent == nil
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
                T3IconImage(systemName: isSimulating ? "stop.circle" : "play.circle")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(T3.ink)
                Text(isSimulating ? "Simulating…" : "Simulate alert")
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                Spacer()
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { TRule() }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSimulating || accessory == nil)
        .opacity(isSimulating ? 0.5 : 1)
    }
    #endif
}
