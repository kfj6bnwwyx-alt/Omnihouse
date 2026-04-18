//
//  T3SmokeAlarmDetailView.swift
//  house connect
//
//  T3/Swiss smoke detector detail — status panel (CLEAR / ALARM / FAULT),
//  stats strip (battery, signal, last test, connection), actions (silence
//  when active, long-press self-test). Hairline dividers only, single
//  orange accent, tabular digits.
//
//  Note: The full-screen critical-alert overlay lives in
//  `SmokeAlarmAlertView` and is driven by `SmokeAlertController` from
//  T3RootView — this detail screen is the calm, config-style view.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3SmokeAlarmDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(SmokeAlarmEventStore.self) private var eventStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(SmokeAlertController.self) private var alertController
    #endif

    // Self-test long-press state (mirrors T3LockDetailView's hold pattern)
    @State private var holdProgress: Double = 0
    @State private var isHolding: Bool = false
    @State private var holdTimer: Timer?
    @State private var testFlash: Bool = false
    private let holdDuration: TimeInterval = T3.LongPress.heavy

    // Pulse animation phase for ALARM state
    @State private var pulsePhase: Bool = false

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    /// Battery level reported by the provider, or nil if this detector
    /// doesn't expose a battery capability (e.g. a hard-wired unit, or
    /// a provider that doesn't surface battery at all).
    private var batteryPercent: Int? {
        guard let accessory else { return nil }
        if case .batteryLevel(let p) = accessory.capability(of: .batteryLevel) {
            return p
        }
        return nil
    }

    private var batteryDisplay: String {
        batteryPercent.map { "\($0)%" } ?? "—"
    }

    private enum AlarmState { case clear, alarm, fault }

    private var alarmState: AlarmState {
        guard let accessory else { return .clear }
        if accessory.isSmokeDetected == true || accessory.isCODetected == true {
            return .alarm
        }
        if !accessory.isReachable { return .fault }
        return .clear
    }

    private var stateLabel: String {
        switch alarmState {
        case .clear: return "CLEAR"
        case .alarm: return "ALARM"
        case .fault: return "FAULT"
        }
    }

    private var stateColor: Color {
        switch alarmState {
        case .clear: return T3.ok
        case .alarm: return T3.danger
        case .fault: return T3.sub
        }
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            if accessory != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        THeader(
                            backLabel: "Room",
                            rightLabel: accessory?.id.provider.displayLabel.uppercased(),
                            onBack: { dismiss() }
                        )

                        TTitle(
                            title: accessory?.name ?? "Smoke Detector",
                            subtitle: nil,
                            isActive: false
                        )

                        TSectionHead(
                            title: "SMOKE DETECTOR",
                            count: roomName?.uppercased()
                        )

                        statusPanel
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.top, 8)
                            .padding(.bottom, 24)

                        TRule()

                        // Stats strip
                        HStack(spacing: 18) {
                            statCell(label: "Battery", value: batteryDisplay)
                            statCell(label: "Signal", value: signalValue)
                            statCell(label: "Tested", value: lastTestedValue)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 18)

                        TRule()

                        // Connection row
                        HStack {
                            TLabel(text: "Connection")
                            Spacer()
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(accessory?.isReachable == true ? T3.ok : T3.danger)
                                    .frame(width: 8, height: 8)
                                Text(accessory?.isReachable == true ? "Online" : "Offline")
                                    .font(T3.inter(14, weight: .medium))
                                    .foregroundStyle(T3.ink)
                            }
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 14)

                        TRule()

                        // Actions
                        if alarmState == .alarm {
                            silenceButton
                        }

                        selfTestButton

                        TRule()

                        // Recent events
                        recentEventsSection

                        Spacer(minLength: 120)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    TLabel(text: "Alarm unavailable")
                    Text("This smoke detector is no longer reported by its provider.")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .multilineTextAlignment(.center)
                }
                .padding(T3.screenPadding)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { pulsePhase = true }
    }

    // MARK: - Status panel

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if alarmState == .alarm && !reduceMotion {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 10, height: 10)
                        .scaleEffect(pulsePhase ? 1.35 : 1.0)
                        .opacity(pulsePhase ? 0.6 : 1.0)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulsePhase)
                } else {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 10, height: 10)
                }
                TLabel(text: "State", color: T3.sub)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(stateLabel)
                    .font(T3.inter(72, weight: .light))
                    .tracking(-2)
                    .foregroundStyle(alarmState == .alarm ? T3.danger : T3.ink)
                    .monospacedDigit()
                Spacer()
            }

            Text(stateDetailCopy)
                .font(T3.inter(13, weight: .regular))
                .foregroundStyle(T3.sub)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Smoke detector state: \(stateLabel)")
    }

    private var stateDetailCopy: String {
        switch alarmState {
        case .clear: return "No smoke or carbon monoxide detected."
        case .alarm: return "Smoke or carbon monoxide detected. Evacuate if unsafe."
        case .fault: return "Detector is unreachable. Check power and signal."
        }
    }

    // MARK: - Stats

    private var signalValue: String {
        // No signal capability yet; surface neutral placeholders so we
        // don't invent a strength reading. TODO(nest): read real value
        // once the Nest/HomeKit provider surfaces signal strength.
        accessory?.isReachable == true ? "Unknown" : "—"
    }

    private var lastTestedValue: String {
        // No self-test timestamp is modeled yet — placeholder until the
        // Nest/HomeKit providers surface it. TODO(nest): read real value.
        "—"
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: label)
            Text(value)
                .font(T3.inter(16, weight: .medium))
                .foregroundStyle(T3.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Silence

    private var silenceButton: some View {
        Button {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task { await alertController.end(reason: .simulationStopped) }
            #endif
        } label: {
            HStack {
                TLabel(text: "Silence alarm", color: T3.ink)
                Spacer()
                T3IconImage(systemName: "bell.slash.fill")
                    .frame(width: 16, height: 16)
                    .foregroundStyle(T3.ink)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 18)
        }
        .buttonStyle(.t3Row)
        .accessibilityLabel("Silence alarm")
        .accessibilityHint("Stops the current smoke alarm")
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Self-test (hold-to-run)

    private var selfTestButton: some View {
        ZStack {
            // Hold progress fill (left-to-right bar along the bottom)
            GeometryReader { proxy in
                Rectangle()
                    .fill(T3.accent.opacity(0.12))
                    .frame(width: proxy.size.width * holdProgress, height: proxy.size.height)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: holdProgress)
            }
            .allowsHitTesting(false)

            HStack {
                TLabel(text: "Run self-test", color: testFlash ? T3.accent : T3.ink)
                Spacer()
                Text("HOLD")
                    .font(T3.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(T3.sub)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 18)
        }
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel("Run self-test")
        .accessibilityHint("Hold to run a detector self-test")
        .accessibilityAddTraits(.isButton)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: holdDuration)
                .onChanged { _ in
                    guard !isHolding else { return }
                    beginHold()
                }
                .onEnded { _ in
                    commitSelfTest()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if isHolding && holdProgress < 1.0 {
                        cancelHold()
                    }
                }
        )
        .overlay(alignment: .bottom) { TRule() }
    }

    private func beginHold() {
        isHolding = true
        holdProgress = 0
        holdTimer?.invalidate()
        let start = Date()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { t in
            let elapsed = Date().timeIntervalSince(start)
            let p = min(1.0, elapsed / holdDuration)
            holdProgress = p
            if p >= 1.0 { t.invalidate() }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            holdProgress = 0
        }
    }

    private func commitSelfTest() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        holdProgress = 1.0

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { testFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                testFlash = false
                holdProgress = 0
            }
            // TODO(nest): wire to a real AccessoryCommand.selfTest case
            // once the Nest/HomeKit provider surfaces it.
        }
    }

    // MARK: - Recent events

    private var recentEventsSection: some View {
        let events = Array(eventStore.events(for: accessoryID.nativeID).prefix(5))
        return VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Recent events", count: events.isEmpty ? "NONE" : "\(events.count)")
            if events.isEmpty {
                HStack {
                    Text("No events recorded yet")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                    Spacer()
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 14)
            } else {
                ForEach(Array(events.enumerated()), id: \.element.id) { pair in
                    HStack(spacing: 14) {
                        Text(pair.element.relativeTime)
                            .font(T3.mono(11))
                            .foregroundStyle(T3.sub)
                            .monospacedDigit()
                            .frame(width: 72, alignment: .leading)

                        Text(pair.element.title)
                            .font(T3.inter(14, weight: .medium))
                            .foregroundStyle(T3.ink)

                        Spacer()

                        Circle()
                            .fill(eventDotColor(pair.element))
                            .frame(width: 8, height: 8)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) {
                        if pair.offset == events.count - 1 { TRule() }
                    }
                }
            }
        }
    }

    private func eventDotColor(_ event: SmokeAlarmEvent) -> Color {
        switch event.iconColor {
        case "red": T3.danger
        case "green": T3.ok
        case "orange": T3.accent
        default: T3.sub
        }
    }
}
